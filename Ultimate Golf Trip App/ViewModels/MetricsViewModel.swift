import Foundation
import SwiftUI

@Observable
class MetricsViewModel {
    var appState: AppState

    // Sheet state
    var showingAddMetric = false
    var showingLogEntry = false
    var showingCreateBet = false
    var showingPresetPicker = false
    var selectedMetric: Metric?
    var selectedCategory: MetricCategory = .onCourse

    // Add metric form
    var newMetricName: String = ""
    var newMetricIcon: String = "📊"
    var newMetricUnit: String = ""
    var newMetricTrackingType: TrackingType = .perRound
    var newMetricCategory: MetricCategory = .onCourse
    var newMetricHigherIsBetter: Bool = true

    // Log entry form
    var entryValue: String = ""
    var entryNotes: String = ""
    var entryPlayerId: UUID?
    var entryRoundId: UUID?

    // Create bet form
    var newBetName: String = ""
    var newBetMetricId: UUID?
    var newBetType: BetType = .highestTotal
    var newBetTargetValue: String = ""
    var newBetParticipants: Set<UUID> = []
    var newBetStake: String = ""
    var newBetIsPot: Bool = false
    var newBetPotAmount: String = ""

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? {
        appState.currentTrip
    }

    // MARK: - Metric Lists

    var onCourseMetrics: [Metric] {
        currentTrip?.onCourseMetrics ?? []
    }

    var offCourseMetrics: [Metric] {
        currentTrip?.offCourseMetrics ?? []
    }

    var allMetrics: [Metric] {
        currentTrip?.metrics ?? []
    }

    var activeBets: [SideBet] {
        currentTrip?.activeSideBets ?? []
    }

    var completedBets: [SideBet] {
        currentTrip?.completedSideBets ?? []
    }

    // MARK: - Leaderboard for a Metric

    struct MetricStanding: Identifiable {
        let id: UUID
        let player: Player
        let total: Double
        let entryCount: Int
    }

    func standings(for metricId: UUID) -> [MetricStanding] {
        guard let trip = currentTrip,
              let metric = trip.metric(withId: metricId) else { return [] }

        return trip.players.map { player in
            let total = trip.totalValue(forMetric: metricId, member: player.id)
            let count = trip.entries(forMetric: metricId, member: player.id).count
            return MetricStanding(id: player.id, player: player, total: total, entryCount: count)
        }
        .sorted { a, b in
            metric.higherIsBetter ? a.total > b.total : a.total < b.total
        }
    }

    func recentEntries(for metricId: UUID, limit: Int = 20) -> [MetricEntry] {
        guard let trip = currentTrip else { return [] }
        return trip.entries(forMetric: metricId)
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func playerName(for id: UUID) -> String {
        currentTrip?.player(withId: id)?.name ?? "Unknown"
    }

    func metricName(for id: UUID) -> String {
        currentTrip?.metric(withId: id)?.name ?? "Unknown"
    }

    // MARK: - Add Metric

    func addMetric() {
        guard !newMetricName.isEmpty, let trip = currentTrip else { return }
        let metric = Metric(
            name: newMetricName,
            icon: newMetricIcon,
            unit: newMetricUnit,
            trackingType: newMetricTrackingType,
            category: newMetricCategory,
            higherIsBetter: newMetricHigherIsBetter
        )
        trip.addMetric(metric)
        appState.saveContext()
        resetMetricForm()
    }

    func addPresetMetric(_ preset: Metric) {
        guard let trip = currentTrip else { return }
        // Don't add duplicates
        guard !trip.metrics.contains(where: { $0.name == preset.name }) else { return }
        // Create a new instance so we don't insert the static template
        let metric = Metric(
            name: preset.name,
            icon: preset.icon,
            unit: preset.unit,
            trackingType: preset.trackingType,
            category: preset.category,
            higherIsBetter: preset.higherIsBetter
        )
        trip.addMetric(metric)
        appState.saveContext()
    }

    func deleteMetric(_ metricId: UUID) {
        guard let trip = currentTrip else { return }
        trip.removeMetric(id: metricId)
        appState.saveContext()
    }

    // MARK: - Log Entry

    func logEntry() {
        guard let metric = selectedMetric,
              let playerId = entryPlayerId,
              let value = Double(entryValue),
              let trip = currentTrip else { return }

        let player = trip.player(withId: playerId)
        let round = entryRoundId.flatMap { trip.round(withId: $0) }

        let entry = MetricEntry(
            metric: metric,
            member: player,
            value: value,
            round: round,
            notes: entryNotes
        )
        trip.addMetricEntry(entry)
        appState.saveContext()
        resetEntryForm()
    }

    func deleteEntry(_ entryId: UUID) {
        guard let trip = currentTrip else { return }
        trip.removeMetricEntry(id: entryId)
        appState.saveContext()
    }

    // MARK: - Side Bets

    func createBet() {
        guard !newBetName.isEmpty,
              let metricId = newBetMetricId,
              newBetParticipants.count >= 2,
              let trip = currentTrip else { return }

        let metric = trip.metric(withId: metricId)
        let target = Double(newBetTargetValue)
        let potAmountValue = Double(newBetPotAmount) ?? 0

        // For pot bets, auto-generate the stake label from the pot amount
        let stakeText: String
        if newBetIsPot && potAmountValue > 0 {
            let total = potAmountValue * Double(newBetParticipants.count)
            stakeText = "$\(String(format: "%.0f", total)) pot"
        } else {
            stakeText = newBetStake.isEmpty ? "Bragging Rights" : newBetStake
        }

        let bet = SideBet(
            name: newBetName,
            metric: metric,
            betType: newBetType,
            targetValue: target,
            participants: Array(newBetParticipants),
            stake: stakeText,
            isPotBet: newBetIsPot,
            potAmount: potAmountValue
        )
        trip.addSideBet(bet)
        appState.saveContext()
        resetBetForm()
    }

    /// Auto-settle: determine the winner from metric data and complete the bet.
    func completeBet(_ betId: UUID) {
        guard let trip = currentTrip,
              let bet = trip.sideBet(withId: betId) else { return }

        let winnerId = determineWinner(for: bet)
        trip.completeSideBet(id: betId, winnerId: winnerId)
        appState.saveContext()
    }

    /// Manually declare a winner and complete the bet.
    func completeBetWithWinner(betId: UUID, winnerId: UUID) {
        guard let trip = currentTrip else { return }
        trip.completeSideBet(id: betId, winnerId: winnerId)
        appState.saveContext()
    }

    func deleteBet(_ betId: UUID) {
        guard let trip = currentTrip else { return }
        trip.removeSideBet(id: betId)
        appState.saveContext()
    }

    /// Get participant players for a bet (used by the winner picker sheet).
    func betParticipants(for bet: SideBet) -> [Player] {
        guard let trip = currentTrip else { return [] }
        return bet.participants.compactMap { trip.player(withId: $0) }
    }

    private func determineWinner(for bet: SideBet) -> UUID? {
        guard let trip = currentTrip,
              let metricId = bet.metric?.id else { return nil }

        let playerTotals = bet.participants.map { playerId in
            (playerId, trip.totalValue(forMetric: metricId, member: playerId))
        }

        switch bet.betType {
        case .highestTotal:
            return playerTotals.max(by: { $0.1 < $1.1 })?.0
        case .lowestTotal:
            return playerTotals.min(by: { $0.1 < $1.1 })?.0
        case .closestToTarget:
            guard let target = bet.targetValue else { return nil }
            return playerTotals.min(by: { abs($0.1 - target) < abs($1.1 - target) })?.0
        case .overUnder, .headToHead:
            // These require manual resolution for now
            return nil
        }
    }

    // MARK: - Form Resets

    func resetMetricForm() {
        newMetricName = ""
        newMetricIcon = "📊"
        newMetricUnit = ""
        newMetricTrackingType = .perRound
        newMetricHigherIsBetter = true
        showingAddMetric = false
    }

    func resetEntryForm() {
        entryValue = ""
        entryNotes = ""
        entryPlayerId = nil
        entryRoundId = nil
        showingLogEntry = false
    }

    func resetBetForm() {
        newBetName = ""
        newBetMetricId = nil
        newBetType = .highestTotal
        newBetTargetValue = ""
        newBetParticipants = []
        newBetStake = ""
        newBetIsPot = false
        newBetPotAmount = ""
        showingCreateBet = false
    }
}

import Foundation
import SwiftUI

/// Renamed from MetricsViewModel — manages challenges (side bets) only.
/// The old metrics tracking system has been removed.
typealias MetricsViewModel = ChallengesViewModel

@MainActor @Observable
class ChallengesViewModel {
    var appState: AppState

    // Edit bet form
    var showingEditBet = false
    var editingBet: SideBet?
    var editBetName: String = ""
    var editBetStake: String = ""

    // Create bet form
    var showingCreateBet = false
    var newBetName: String = ""
    var newBetType: BetType = .lowRound
    var newBetTargetValue: String = ""
    var newBetParticipants: Set<UUID> = []
    var newBetStake: String = ""
    var newBetIsPot: Bool = false
    var newBetPotAmount: String = ""
    var newBetRoundId: UUID?
    var newBetUseNetScoring: Bool = false
    var newBetRequiresPutts: Bool = false
    var newBetCustomMetricName: String = ""
    var newBetCustomHighestWins: Bool = true
    var newBetIsTripWide: Bool = false

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? {
        appState.currentTrip
    }

    var activeBets: [SideBet] {
        currentTrip?.activeSideBets ?? []
    }

    var completedBets: [SideBet] {
        currentTrip?.completedSideBets ?? []
    }

    func playerName(for id: UUID) -> String {
        currentTrip?.player(withId: id)?.name ?? "Unknown"
    }

    // MARK: - Challenge CRUD

    func createBet() {
        guard !newBetName.isEmpty,
              newBetParticipants.count >= 2,
              let trip = currentTrip else { return }

        // Validate all participants still exist in the trip
        let validParticipants = newBetParticipants.filter { trip.player(withId: $0) != nil }
        guard validParticipants.count >= 2 else { return }
        newBetParticipants = validParticipants

        // Round-based challenges require a round UNLESS trip-wide
        if newBetType.isRoundBased && !newBetIsTripWide {
            guard newBetRoundId != nil else { return }
        }

        let target = Double(newBetTargetValue)
        let potAmountValue = Double(newBetPotAmount) ?? 0
        let round = newBetRoundId.flatMap { trip.round(withId: $0) }

        let stakeText: String = newBetStake.isEmpty ? "Bragging Rights" : newBetStake

        let bet = SideBet(
            name: newBetName,
            betType: newBetType,
            targetValue: target,
            participants: Array(newBetParticipants),
            stake: stakeText,
            isPotBet: newBetIsPot,
            potAmount: potAmountValue,
            round: newBetIsTripWide ? nil : round,
            useNetScoring: newBetUseNetScoring,
            requiresPuttsData: newBetRequiresPutts,
            isTripWide: newBetIsTripWide
        )

        // Set custom challenge fields
        if newBetType.isCustom {
            bet.customMetricName = newBetCustomMetricName
            bet.customHighestWins = newBetCustomHighestWins
        }

        trip.addSideBet(bet)
        appState.saveContext()
        resetBetForm()
    }

    /// Auto-settle: determine the winner from scorecard data and complete the bet.
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

    func startEditingBet(_ bet: SideBet) {
        editingBet = bet
        editBetName = bet.name
        editBetStake = bet.stake
        showingEditBet = true
    }

    func saveBetEdits() {
        guard let bet = editingBet else { return }
        let trimmedName = editBetName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        bet.name = trimmedName
        bet.stake = editBetStake
        appState.saveContext()
        resetEditBetForm()
    }

    private func resetEditBetForm() {
        editingBet = nil
        editBetName = ""
        editBetStake = ""
        showingEditBet = false
    }

    /// Get participant players for a bet.
    func betParticipants(for bet: SideBet) -> [Player] {
        guard let trip = currentTrip else { return [] }
        return bet.participants.compactMap { trip.player(withId: $0) }
    }

    // MARK: - Custom Challenge Values

    func updateCustomValue(betId: UUID, playerId: UUID, value: Double) {
        guard let trip = currentTrip,
              let bet = trip.sideBet(withId: betId) else { return }
        bet.updateCustomValue(for: playerId, value: value)
        appState.saveContext()
    }

    /// Add a cumulative entry for a trip-wide custom challenge.
    func addCustomEntry(betId: UUID, playerId: UUID, value: Double, note: String? = nil) {
        guard let trip = currentTrip,
              let bet = trip.sideBet(withId: betId) else { return }
        bet.addCustomEntry(for: playerId, value: value, note: note)
        appState.saveContext()
    }

    // MARK: - Winner Determination

    private func determineWinner(for bet: SideBet) -> UUID? {
        // Custom challenges: compare custom values
        if bet.challengeType.isCustom {
            return determineCustomWinner(for: bet)
        }

        // Round-based challenges: compare scorecard metrics
        if bet.isRoundBased {
            return determineRoundBasedWinner(for: bet)
        }

        // Non-round-based challenges without metrics require manual settlement
        return nil
    }

    private func determineRoundBasedWinner(for bet: SideBet) -> UUID? {
        if bet.isTripWide {
            guard let trip = bet.trip else { return nil }
            return Self.determineTripWideWinner(for: bet, rounds: trip.rounds)
        }
        guard let round = bet.round else { return nil }
        return Self.determineRoundBasedWinner(for: bet, round: round)
    }

    /// Determine winner for a trip-wide scorecard challenge by aggregating across all rounds.
    static func determineTripWideWinner(for bet: SideBet, rounds: [Round]) -> UUID? {
        let playerMetrics: [(UUID, Int)] = bet.participants.compactMap { playerId in
            let total = aggregateMetricAcrossRounds(playerId: playerId, bet: bet, rounds: rounds)
            guard let value = total, value > 0 || bet.challengeType == .fewest3Putts || bet.challengeType == .most3Putts else { return nil }
            return (playerId, value)
        }

        guard !playerMetrics.isEmpty else { return nil }

        let best: (UUID, Int)?
        if bet.challengeType.highestWins {
            best = playerMetrics.max(by: { $0.1 < $1.1 })
        } else {
            best = playerMetrics.min(by: { $0.1 < $1.1 })
        }

        guard let winner = best else { return nil }
        let tiedCount = playerMetrics.filter { $0.1 == winner.1 }.count
        return tiedCount == 1 ? winner.0 : nil
    }

    /// Aggregate a metric across all rounds for a player.
    static func aggregateMetricAcrossRounds(playerId: UUID, bet: SideBet, rounds: [Round]) -> Int? {
        var total = 0
        var hasData = false
        for round in rounds {
            if let value = metricForPlayer(playerId, bet: bet, round: round) {
                total += value
                hasData = true
            }
        }
        return hasData ? total : nil
    }

    /// Static helper so other view models (e.g. ScorecardViewModel) can auto-settle.
    static func determineRoundBasedWinner(for bet: SideBet, round: Round) -> UUID? {
        let playerMetrics: [(UUID, Int)] = bet.participants.compactMap { playerId in
            guard let value = metricForPlayer(playerId, bet: bet, round: round) else { return nil }
            guard value > 0 || bet.challengeType == .fewest3Putts || bet.challengeType == .most3Putts else { return nil }
            return (playerId, value)
        }

        guard !playerMetrics.isEmpty else { return nil }

        let best: (UUID, Int)?
        if bet.challengeType.highestWins {
            best = playerMetrics.max(by: { $0.1 < $1.1 })
        } else {
            best = playerMetrics.min(by: { $0.1 < $1.1 })
        }

        guard let winner = best else { return nil }
        let tiedCount = playerMetrics.filter { $0.1 == winner.1 }.count
        return tiedCount == 1 ? winner.0 : nil
    }

    private func determineCustomWinner(for bet: SideBet) -> UUID? {
        let values = bet.customValues
        let playerValues: [(UUID, Double)] = bet.participants.compactMap { playerId in
            guard let value = values[playerId] else { return nil }
            return (playerId, value)
        }

        guard playerValues.count == bet.participants.count else { return nil }

        let best: (UUID, Double)?
        if bet.customHighestWins {
            best = playerValues.max(by: { $0.1 < $1.1 })
        } else {
            best = playerValues.min(by: { $0.1 < $1.1 })
        }

        guard let winner = best else { return nil }
        let tiedCount = playerValues.filter { $0.1 == winner.1 }.count
        return tiedCount == 1 ? winner.0 : nil
    }

    // MARK: - Shared Metric Computation

    /// Compute the relevant metric value for a player in a round-based challenge.
    /// Shared across winner determination, card display, and settlement results.
    static func metricForPlayer(_ playerId: UUID, bet: SideBet, round: Round) -> Int? {
        guard let card = round.scorecard(forPlayer: playerId) else { return nil }

        switch bet.challengeType {
        case .lowRound, .headToHeadRound:
            let score = bet.useNetScoring ? card.totalNet : card.totalGross
            return score > 0 ? score : nil
        case .mostBirdies:
            guard card.holesCompleted > 0 else { return nil }
            return card.holeScores.filter {
                $0.isCompleted && (bet.useNetScoring ? $0.netScoreToPar <= -1 : $0.scoreToPar <= -1)
            }.count
        case .fewestPutts:
            guard card.holesCompleted > 0 else { return nil }
            return card.totalPutts
        case .fewest3Putts, .most3Putts:
            guard card.holesCompleted > 0 else { return nil }
            return card.holeScores.filter { $0.isCompleted && $0.putts >= 3 }.count
        default:
            return nil
        }
    }

    /// Label for the metric value in a given challenge type.
    static func metricLabel(for type: ChallengeType) -> String {
        switch type {
        case .lowRound, .headToHeadRound: return "Score"
        case .mostBirdies: return "Birdies"
        case .fewestPutts: return "Putts"
        case .fewest3Putts, .most3Putts: return "3-Putts"
        default: return "Value"
        }
    }

    // MARK: - Live Standings

    /// A single player's standing in a challenge.
    struct PlayerStanding: Identifiable {
        let playerId: UUID
        let playerName: String
        let value: Double
        let label: String      // e.g. "72", "3 birdies", "28 putts"
        let isLeader: Bool

        var id: UUID { playerId }
    }

    /// Compute real-time standings for any challenge type.
    func liveStandings(for bet: SideBet) -> [PlayerStanding] {
        guard let trip = currentTrip else { return [] }

        if bet.challengeType.isCustom {
            return customStandings(for: bet, trip: trip)
        }
        if bet.isRoundBased {
            return roundBasedStandings(for: bet, trip: trip)
        }
        return []
    }

    private func roundBasedStandings(for bet: SideBet, trip: Trip) -> [PlayerStanding] {
        let metricName = Self.metricLabel(for: bet.challengeType)

        let standings: [PlayerStanding]
        if bet.isTripWide {
            // Aggregate across all trip rounds
            standings = bet.participants.compactMap { playerId in
                guard let player = trip.player(withId: playerId),
                      let value = Self.aggregateMetricAcrossRounds(playerId: playerId, bet: bet, rounds: trip.rounds) else { return nil }
                return PlayerStanding(
                    playerId: playerId,
                    playerName: player.name,
                    value: Double(value),
                    label: "\(value) \(metricName)",
                    isLeader: false
                )
            }
        } else {
            guard let round = bet.round else { return [] }
            standings = bet.participants.compactMap { playerId in
                guard let player = trip.player(withId: playerId),
                      let value = Self.metricForPlayer(playerId, bet: bet, round: round) else { return nil }
                return PlayerStanding(
                    playerId: playerId,
                    playerName: player.name,
                    value: Double(value),
                    label: "\(value) \(metricName)",
                    isLeader: false
                )
            }
        }

        let sorted: [PlayerStanding]
        if bet.challengeType.highestWins {
            sorted = standings.sorted { $0.value > $1.value }
        } else {
            sorted = standings.sorted { $0.value < $1.value }
        }

        guard let bestValue = sorted.first?.value else { return sorted }
        return sorted.map {
            PlayerStanding(
                playerId: $0.playerId,
                playerName: $0.playerName,
                value: $0.value,
                label: $0.label,
                isLeader: $0.value == bestValue
            )
        }
    }

    private func customStandings(for bet: SideBet, trip: Trip) -> [PlayerStanding] {
        let values = bet.customValues
        let metricName = bet.customMetricName.isEmpty ? "Value" : bet.customMetricName

        let standings: [PlayerStanding] = bet.participants.compactMap { playerId in
            guard let player = trip.player(withId: playerId) else { return nil }
            let value = values[playerId] ?? 0
            let hasValue = values[playerId] != nil
            return PlayerStanding(
                playerId: playerId,
                playerName: player.name,
                value: value,
                label: hasValue ? "\(value.formatted()) \(metricName)" : "—",
                isLeader: false
            )
        }

        let sorted: [PlayerStanding]
        if bet.customHighestWins {
            sorted = standings.sorted { $0.value > $1.value }
        } else {
            sorted = standings.sorted { $0.value < $1.value }
        }

        let hasAnyValue = values.values.contains { $0 != 0 }
        guard hasAnyValue, let bestValue = sorted.first?.value else { return sorted }
        return sorted.map {
            PlayerStanding(
                playerId: $0.playerId,
                playerName: $0.playerName,
                value: $0.value,
                label: $0.label,
                isLeader: $0.value == bestValue
            )
        }
    }

    // MARK: - Quick Create Templates

    /// Tracks whether the form was opened from a template (skips type selection UI).
    var isFromTemplate: Bool = false

    /// Pre-fill the create form from a challenge template.
    func applyTemplate(_ template: ChallengeTemplate) {
        resetBetForm()
        isFromTemplate = true
        newBetName = template.displayName
        newBetType = template.betType
        newBetUseNetScoring = template.useNetScoring
        newBetRequiresPutts = template.requiresPutts
        newBetIsTripWide = template.isTripWide

        // Select all players by default
        if let trip = currentTrip {
            newBetParticipants = Set(trip.players.map(\.id))

            // Auto-select the round if there's only one (or the most recent incomplete one)
            let activeRounds = trip.rounds.filter { !$0.isComplete }
            if activeRounds.count == 1 {
                newBetRoundId = activeRounds.first?.id
            } else if let latest = trip.rounds.last {
                newBetRoundId = latest.id
            }
        }

        showingCreateBet = true
    }

    // MARK: - Form Reset

    func resetBetForm() {
        isFromTemplate = false
        newBetName = ""
        newBetType = .lowRound
        newBetTargetValue = ""
        newBetParticipants = []
        newBetStake = ""
        newBetIsPot = false
        newBetPotAmount = ""
        newBetRoundId = nil
        newBetUseNetScoring = false
        newBetRequiresPutts = false
        newBetCustomMetricName = ""
        newBetCustomHighestWins = true
        newBetIsTripWide = false
        showingCreateBet = false
    }
}

// MARK: - Challenge Templates

enum ChallengeTemplate: String, CaseIterable, Identifiable {
    // Single-round templates
    case lowRoundGross = "lowRoundGross"
    case lowRoundNet = "lowRoundNet"
    case headToHead = "headToHead"
    case mostBirdiesGross = "mostBirdiesGross"
    case mostBirdiesNet = "mostBirdiesNet"
    case fewestPutts = "fewestPutts"
    case fewest3Putts = "fewest3Putts"
    case most3Putts = "most3Putts"
    // Trip-wide templates
    case mostBirdiesTrip = "mostBirdiesTrip"
    case fewestPuttsTrip = "fewestPuttsTrip"
    case lowTotalTrip = "lowTotalTrip"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lowRoundGross: return "Low Round (Gross)"
        case .lowRoundNet: return "Low Round (Net)"
        case .headToHead: return "Head-to-Head Matchup"
        case .mostBirdiesGross: return "Most Birdies (Gross)"
        case .mostBirdiesNet: return "Most Birdies (Net)"
        case .fewestPutts: return "Fewest Putts"
        case .fewest3Putts: return "Fewest 3-Putts"
        case .most3Putts: return "Most 3-Putts"
        case .mostBirdiesTrip: return "Most Birdies (Trip)"
        case .fewestPuttsTrip: return "Fewest Putts (Trip)"
        case .lowTotalTrip: return "Low Total (Trip)"
        }
    }

    var icon: String {
        switch self {
        case .lowRoundGross, .lowRoundNet: return "medal.fill"
        case .headToHead: return "person.2.fill"
        case .mostBirdiesGross, .mostBirdiesNet, .mostBirdiesTrip: return "bird.fill"
        case .fewestPutts, .fewest3Putts, .fewestPuttsTrip: return "flag.fill"
        case .most3Putts: return "hand.thumbsdown.fill"
        case .lowTotalTrip: return "trophy.fill"
        }
    }

    var betType: BetType {
        switch self {
        case .lowRoundGross, .lowRoundNet, .lowTotalTrip: return .lowRound
        case .headToHead: return .headToHeadRound
        case .mostBirdiesGross, .mostBirdiesNet, .mostBirdiesTrip: return .mostBirdies
        case .fewestPutts, .fewestPuttsTrip: return .fewestPutts
        case .fewest3Putts: return .fewest3Putts
        case .most3Putts: return .most3Putts
        }
    }

    var useNetScoring: Bool {
        switch self {
        case .lowRoundNet, .mostBirdiesNet, .lowTotalTrip: return true
        default: return false
        }
    }

    /// Whether this template requires putts data in the scorecard.
    var requiresPutts: Bool {
        switch self {
        case .fewestPutts, .fewest3Putts, .most3Putts, .fewestPuttsTrip:
            return true
        default:
            return false
        }
    }

    /// Whether this template creates a trip-wide challenge.
    var isTripWide: Bool {
        switch self {
        case .mostBirdiesTrip, .fewestPuttsTrip, .lowTotalTrip:
            return true
        default:
            return false
        }
    }
}

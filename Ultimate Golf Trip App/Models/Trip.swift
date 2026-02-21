import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var shareCode: String
    var createdAt: Date
    var ownerProfileId: UUID?

    // MARK: - Trip Rules (match play points — Ryder Cup style defaults)

    var pointsPerMatchWin: Double
    var pointsPerMatchHalve: Double
    var pointsPerMatchLoss: Double

    // MARK: - Relationships (cascade delete — deleting a trip removes all children)

    @Relationship(deleteRule: .cascade)
    var players: [Player]

    @Relationship(deleteRule: .cascade)
    var teams: [Team]

    @Relationship(deleteRule: .cascade)
    var courses: [Course]

    @Relationship(deleteRule: .cascade)
    var rounds: [Round]

    @Relationship(deleteRule: .cascade)
    var sideGames: [SideGame]

    // War Room
    @Relationship(deleteRule: .cascade)
    var warRoomEvents: [WarRoomEvent]

    @Relationship(deleteRule: .cascade)
    var travelStatuses: [TravelStatus]

    @Relationship(deleteRule: .cascade)
    var polls: [Poll]

    // Side Games: On-Course & Off-Course Tracking
    @Relationship(deleteRule: .cascade)
    var metrics: [Metric]

    @Relationship(deleteRule: .cascade)
    var metricEntries: [MetricEntry]

    @Relationship(deleteRule: .cascade)
    var sideBets: [SideBet]

    init(
        id: UUID = UUID(),
        name: String,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
        players: [Player] = [],
        teams: [Team] = [],
        courses: [Course] = [],
        rounds: [Round] = [],
        sideGames: [SideGame] = [],
        shareCode: String = "",
        createdAt: Date = Date(),
        ownerProfileId: UUID? = nil,
        warRoomEvents: [WarRoomEvent] = [],
        travelStatuses: [TravelStatus] = [],
        polls: [Poll] = [],
        metrics: [Metric] = [],
        metricEntries: [MetricEntry] = [],
        sideBets: [SideBet] = [],
        pointsPerMatchWin: Double = 1.0,
        pointsPerMatchHalve: Double = 0.5,
        pointsPerMatchLoss: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.players = players
        self.teams = teams
        self.courses = courses
        self.rounds = rounds
        self.sideGames = sideGames
        self.shareCode = shareCode.isEmpty ? Trip.generateShareCode() : shareCode
        self.createdAt = createdAt
        self.ownerProfileId = ownerProfileId
        self.warRoomEvents = warRoomEvents
        self.travelStatuses = travelStatuses
        self.polls = polls
        self.metrics = metrics
        self.metricEntries = metricEntries
        self.sideBets = sideBets
        self.pointsPerMatchWin = pointsPerMatchWin
        self.pointsPerMatchHalve = pointsPerMatchHalve
        self.pointsPerMatchLoss = pointsPerMatchLoss
    }

    // MARK: - Computed Properties

    var dateRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)
        return "\(start) - \(end)"
    }

    var numberOfDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1
    }

    var completedRounds: [Round] {
        rounds.filter { $0.isComplete }
    }

    var activeRound: Round? {
        rounds.first { !$0.isComplete && $0.scorecards.contains { $0.holesCompleted > 0 } }
    }

    func isOwner(_ userProfileId: UUID?) -> Bool {
        guard let userProfileId, let ownerProfileId else { return false }
        return userProfileId == ownerProfileId
    }

    // MARK: - Existing Lookups

    func player(withId id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    func team(withId id: UUID) -> Team? {
        teams.first { $0.id == id }
    }

    func course(withId id: UUID) -> Course? {
        courses.first { $0.id == id }
    }

    func round(withId id: UUID) -> Round? {
        rounds.first { $0.id == id }
    }

    func playersOnTeam(_ teamId: UUID) -> [Player] {
        players.filter { $0.team?.id == teamId }
    }

    // MARK: - War Room Lookups

    func warRoomEvent(withId id: UUID) -> WarRoomEvent? {
        warRoomEvents.first { $0.id == id }
    }

    func travelStatus(forPlayer playerId: UUID) -> TravelStatus? {
        travelStatuses.first { $0.player?.id == playerId }
    }

    func poll(withId id: UUID) -> Poll? {
        polls.first { $0.id == id }
    }

    var nextUpcomingEvent: WarRoomEvent? {
        warRoomEvents
            .filter { $0.isUpcoming }
            .sorted { $0.dateTime < $1.dateTime }
            .first
    }

    var activePolls: [Poll] {
        polls.filter { $0.isActive }
    }

    // MARK: - Mutations (no longer `mutating` — reference type)

    func addPlayer(_ player: Player) {
        player.trip = self
        players.append(player)
    }

    func removePlayer(id: UUID) {
        players.removeAll { $0.id == id }
        // Remove from teams
        for team in teams {
            team.players.removeAll { $0.id == id }
        }
    }

    func updateRound(_ round: Round) {
        // With reference types, the round is already mutated in-place
        // This method is kept for API compatibility
    }

    func addWarRoomEvent(_ event: WarRoomEvent) {
        event.trip = self
        warRoomEvents.append(event)
    }

    func updateWarRoomEvent(_ event: WarRoomEvent) {
        // With reference types, the event is already mutated in-place
    }

    func removeWarRoomEvent(id: UUID) {
        warRoomEvents.removeAll { $0.id == id }
    }

    func updateTravelStatus(_ status: TravelStatus) {
        if let existing = travelStatuses.first(where: { $0.player?.id == status.player?.id }) {
            existing.status = status.status
            existing.updatedAt = status.updatedAt
            existing.flightInfo = status.flightInfo
            existing.eta = status.eta
        } else {
            status.trip = self
            travelStatuses.append(status)
        }
    }

    func addPoll(_ poll: Poll) {
        poll.trip = self
        polls.append(poll)
    }

    func updatePoll(_ poll: Poll) {
        // With reference types, the poll is already mutated in-place
    }

    func closePoll(id: UUID) {
        if let poll = polls.first(where: { $0.id == id }) {
            poll.isActive = false
        }
    }

    // MARK: - Metric / Challenge Lookups

    func metric(withId id: UUID) -> Metric? {
        metrics.first { $0.id == id }
    }

    func sideBet(withId id: UUID) -> SideBet? {
        sideBets.first { $0.id == id }
    }

    func entries(forMetric metricId: UUID) -> [MetricEntry] {
        metricEntries.filter { $0.metric?.id == metricId }
    }

    func entries(forMember memberId: UUID) -> [MetricEntry] {
        metricEntries.filter { $0.member?.id == memberId }
    }

    func entries(forMetric metricId: UUID, member memberId: UUID) -> [MetricEntry] {
        metricEntries.filter { $0.metric?.id == metricId && $0.member?.id == memberId }
    }

    func totalValue(forMetric metricId: UUID, member memberId: UUID) -> Double {
        entries(forMetric: metricId, member: memberId).reduce(0) { $0 + $1.value }
    }

    var onCourseMetrics: [Metric] {
        metrics.filter { $0.category == .onCourse }
    }

    var offCourseMetrics: [Metric] {
        metrics.filter { $0.category == .offCourse }
    }

    var activeSideBets: [SideBet] {
        sideBets.filter { $0.isActive }
    }

    var completedSideBets: [SideBet] {
        sideBets.filter { $0.isCompleted }
    }

    func bets(forMetric metricId: UUID) -> [SideBet] {
        sideBets.filter { $0.metric?.id == metricId }
    }

    // MARK: - Metric / Challenge Mutations

    func addMetric(_ metric: Metric) {
        metric.trip = self
        metrics.append(metric)
    }

    func updateMetric(_ metric: Metric) {
        // With reference types, the metric is already mutated in-place
    }

    func removeMetric(id: UUID) {
        metrics.removeAll { $0.id == id }
        metricEntries.removeAll { $0.metric?.id == id }
        sideBets.removeAll { $0.metric?.id == id }
    }

    func addMetricEntry(_ entry: MetricEntry) {
        entry.trip = self
        metricEntries.append(entry)
    }

    func updateMetricEntry(_ entry: MetricEntry) {
        // With reference types, the entry is already mutated in-place
    }

    func removeMetricEntry(id: UUID) {
        metricEntries.removeAll { $0.id == id }
    }

    func addSideBet(_ bet: SideBet) {
        bet.trip = self
        sideBets.append(bet)
    }

    func updateSideBet(_ bet: SideBet) {
        // With reference types, the bet is already mutated in-place
    }

    func completeSideBet(id: UUID, winnerId: UUID?) {
        if let bet = sideBets.first(where: { $0.id == id }) {
            bet.status = .completed
            bet.winnerId = winnerId
        }
    }

    func removeSideBet(id: UUID) {
        sideBets.removeAll { $0.id == id }
    }

    // MARK: - Private Helpers

    private static func generateShareCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in characters[Int.random(in: 0..<characters.count)] })
    }
}

import Foundation
import SwiftData

@Model
final class Trip {
    var id: UUID = UUID()
    var name: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var shareCode: String = ""
    var createdAt: Date = Date()
    var ownerProfileId: UUID?

    // MARK: - Trip Rules (match play points — Ryder Cup style defaults)

    var pointsPerMatchWin: Double = 1.0
    var pointsPerMatchHalve: Double = 0.5
    var pointsPerMatchLoss: Double = 0.0

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

    // Challenges
    @Relationship(deleteRule: .cascade)
    var sideBets: [SideBet]

    /// IDs of entities that were explicitly deleted locally.
    /// Prevents cloud sync from re-adding them.
    var deletedPlayerIds: [String] = []
    var deletedCourseIds: [String] = []
    var deletedTeamIds: [String] = []
    var deletedSideGameIds: [String] = []
    var deletedSideBetIds: [String] = []
    var deletedWarRoomEventIds: [String] = []
    var deletedRoundIds: [String] = []

    /// Schema version for forward-compatibility. Old clients that don't understand
    /// newer fields should not push data that regresses values set by newer clients.
    var schemaVersion: Int = 2

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
        rounds.first { !$0.isComplete && $0.scorecards.contains(where: { $0.holesCompleted > 0 }) }
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
        // Track deletion so cloud sync won't re-add this player
        if !deletedPlayerIds.contains(id.uuidString) {
            deletedPlayerIds.append(id.uuidString)
        }
        players.removeAll { $0.id == id }
        // Remove from teams
        for team in teams {
            team.players.removeAll { $0.id == id }
        }
        // Remove from round playerIds and their scorecards
        for round in rounds {
            round.playerIds.removeAll { $0 == id }
            round.scorecards.removeAll { $0.player?.id == id }
        }
        // Remove from side game participants
        for game in sideGames {
            game.participantIds.removeAll { $0 == id }
        }
        // Remove from challenge participants
        for bet in sideBets {
            bet.participants.removeAll { $0 == id }
        }
        // Remove travel statuses
        travelStatuses.removeAll { $0.player?.id == id }
        // Delete from CloudKit in the background
        Task {
            await CloudKitService.shared.deleteRecord(id: id)
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
        if !deletedWarRoomEventIds.contains(id.uuidString) {
            deletedWarRoomEventIds.append(id.uuidString)
        }
        warRoomEvents.removeAll { $0.id == id }
        Task { await CloudKitService.shared.deleteRecord(id: id) }
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

    // MARK: - Challenge Lookups

    func sideBet(withId id: UUID) -> SideBet? {
        sideBets.first { $0.id == id }
    }

    var activeSideBets: [SideBet] {
        sideBets.filter { $0.isActive }
    }

    var completedSideBets: [SideBet] {
        sideBets.filter { $0.isCompleted }
    }

    // MARK: - Challenge Mutations

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
        if !deletedSideBetIds.contains(id.uuidString) {
            deletedSideBetIds.append(id.uuidString)
        }
        sideBets.removeAll { $0.id == id }
        Task { await CloudKitService.shared.deleteRecord(id: id) }
    }

    // MARK: - Rounds

    func removeRound(id: UUID) {
        if !deletedRoundIds.contains(id.uuidString) {
            deletedRoundIds.append(id.uuidString)
        }
        rounds.removeAll { $0.id == id }
        // Also remove any side bets tied to this round
        for bet in sideBets where bet.round?.id == id {
            removeSideBet(id: bet.id)
        }
        Task { await CloudKitService.shared.deleteRecord(id: id) }
    }

    // MARK: - Private Helpers

    private static func generateShareCode() -> String {
        let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in characters[Int.random(in: 0..<characters.count)] })
    }
}

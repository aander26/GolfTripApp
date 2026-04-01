import Foundation

@MainActor @Observable
class LeaderboardViewModel {
    var appState: AppState
    var selectedRoundId: UUID?
    var showingNetScores = true

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? { appState.currentTrip }

    // MARK: - Overall Leaderboard

    var overallLeaderboard: [LeaderboardEntry] {
        guard let trip = currentTrip else { return [] }
        return LeaderboardEngine.generateLeaderboard(trip: trip, sortByNet: showingNetScores)
    }

    // MARK: - Round Leaderboard

    var roundLeaderboard: [LeaderboardEntry] {
        guard let trip = currentTrip,
              let roundId = selectedRoundId,
              let round = trip.round(withId: roundId),
              let course = round.course else { return [] }
        return LeaderboardEngine.generateRoundLeaderboard(
            round: round,
            course: course,
            players: trip.players,
            sortByNet: showingNetScores
        )
    }

    // MARK: - Team Leaderboard

    var teamLeaderboard: [(team: Team, totalNet: Int, netToPar: Int)] {
        guard let trip = currentTrip else { return [] }
        return LeaderboardEngine.generateTeamLeaderboard(trip: trip)
    }

    // MARK: - Team Match Play

    /// Trip-level team points standings (Ryder Cup style)
    var teamPointsStandings: [TeamPointsStanding] {
        guard let trip = currentTrip else { return [] }
        return TeamMatchPlayEngine.generateTeamPointsStandings(trip: trip)
    }

    /// Per-round match results (individual match breakdowns for all formats)
    var teamMatchResults: [RoundTeamMatchResult] {
        guard let trip = currentTrip else { return [] }
        return trip.rounds.enumerated().compactMap { index, round in
            guard let course = round.course else { return nil }
            let rule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
            var result = TeamMatchPlayEngine.calculateRoundResults(
                round: round,
                course: course,
                players: trip.players,
                teams: trip.teams,
                scoringRule: rule
            )
            result.roundLabel = "R\(index + 1): \(course.name)"
            let hasContent = !result.individualMatches.isEmpty || !result.ninesMatches.isEmpty || !result.teamScores.isEmpty || !result.teamNinesScores.isEmpty
            return hasContent ? result : nil
        }
    }

    // MARK: - Stableford Leaderboard

    var stablefordLeaderboard: [LeaderboardEntry] {
        guard let trip = currentTrip else { return [] }
        return LeaderboardEngine.generateStablefordLeaderboard(trip: trip)
    }

    // MARK: - Available Rounds

    var availableRounds: [(id: UUID, label: String)] {
        guard let trip = currentTrip else { return [] }
        return trip.rounds.enumerated().map { index, round in
            let courseName = round.course?.name ?? "Round"
            return (id: round.id, label: "R\(index + 1): \(courseName)")
        }
    }

    func selectRound(_ roundId: UUID?) {
        selectedRoundId = roundId
    }
}

import Foundation

/// Engine for computing team competition results and trip-level points standings.
/// Supports multiple scoring formats per course: traditional match play, singles match play,
/// team stroke play, and team best ball.
struct TeamMatchPlayEngine {

    // MARK: - Auto-Pairing

    /// Generate match pairings for a round based on team rosters.
    static func generatePairings(
        team1Players: [Player],
        team2Players: [Player]
    ) -> [MatchPairing] {
        let count = min(team1Players.count, team2Players.count)
        guard count > 0 else { return [] }
        return (0..<count).map { i in
            MatchPairing(
                player1Id: team1Players[i].id,
                player2Id: team2Players[i].id
            )
        }
    }

    // MARK: - Resolve Scoring Rule

    /// Determine the scoring rule for a round: course-level rule takes priority, then trip defaults.
    static func resolveScoringRule(round: Round, trip: Trip) -> TeamScoringRule {
        // Course-level rule (explicitly assigned by user)
        if let courseRule = round.course?.teamScoringRule {
            return courseRule
        }
        // Trip-level defaults as fallback (traditional match play with trip's points)
        return TeamScoringRule(
            format: .traditionalMatchPlay,
            pointsPerWin: trip.pointsPerMatchWin,
            pointsPerHalve: trip.pointsPerMatchHalve,
            pointsPerLoss: trip.pointsPerMatchLoss
        )
    }

    // MARK: - Round-Level Results

    /// Calculate team results for a round using the appropriate scoring format.
    static func calculateRoundResults(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        let emptyResult = RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            individualMatches: [],
            teamScores: []
        )

        guard teams.count == 2 else { return emptyResult }

        switch scoringRule.format {
        case .traditionalMatchPlay, .singlesMatchPlay:
            return calculateMatchPlayRound(
                round: round,
                course: course,
                players: players,
                teams: teams,
                scoringRule: scoringRule
            )
        case .teamStrokePlay:
            return calculateTeamStrokePlayRound(
                round: round,
                course: course,
                players: players,
                teams: teams,
                scoringRule: scoringRule
            )
        case .teamBestBall:
            return calculateTeamBestBallRound(
                round: round,
                course: course,
                players: players,
                teams: teams,
                scoringRule: scoringRule
            )
        }
    }

    // MARK: - Match Play (Traditional & Singles)

    /// Calculate 1v1 match play results (used for both traditional and singles formats).
    private static func calculateMatchPlayRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        // Determine pairings
        let pairings: [MatchPairing]
        if round.matchPairings.isEmpty {
            let team1Players = players
                .filter { $0.team?.id == teams[0].id }
                .filter { round.playerIds.contains($0.id) }
            let team2Players = players
                .filter { $0.team?.id == teams[1].id }
                .filter { round.playerIds.contains($0.id) }
            pairings = generatePairings(team1Players: team1Players, team2Players: team2Players)
        } else {
            pairings = round.matchPairings
        }

        let matches: [IndividualMatchResult] = pairings.compactMap { pairing in
            guard let card1 = round.scorecard(forPlayer: pairing.player1Id),
                  let card2 = round.scorecard(forPlayer: pairing.player2Id),
                  let p1 = players.first(where: { $0.id == pairing.player1Id }),
                  let p2 = players.first(where: { $0.id == pairing.player2Id })
            else { return nil }

            guard card1.holesCompleted > 0 || card2.holesCompleted > 0 else { return nil }

            let matchResult = ScoringEngine.calculateMatchPlay(
                player1Card: card1,
                player2Card: card2,
                holes: course.holes
            )

            return IndividualMatchResult(
                player1Id: p1.id,
                player2Id: p2.id,
                player1Name: p1.name,
                player2Name: p2.name,
                player1TeamId: p1.team?.id ?? UUID(),
                player2TeamId: p2.team?.id ?? UUID(),
                matchPlayResult: matchResult
            )
        }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            individualMatches: matches,
            teamScores: []
        )
    }

    // MARK: - Team Stroke Play

    /// Calculate team stroke play: sum each team's net scores, lower team total wins.
    private static func calculateTeamStrokePlayRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        let teamScores: [TeamRoundScore] = teams.map { team in
            let teamPlayers = players
                .filter { $0.team?.id == team.id }
                .filter { round.playerIds.contains($0.id) }

            var totalGross = 0
            var totalNet = 0
            var totalPar = 0

            for player in teamPlayers {
                guard let card = round.scorecard(forPlayer: player.id) else { continue }
                let processed = ScoringEngine.calculateStrokePlay(scorecard: card, holes: course.holes)
                totalGross += processed.totalGross
                totalNet += processed.totalNet
                totalPar += processed.holeScores.filter { $0.isCompleted }.reduce(0) { $0 + $1.par }
            }

            return TeamRoundScore(
                teamId: team.id,
                teamName: team.name,
                teamColor: team.color,
                totalGrossScore: totalGross,
                totalNetScore: totalNet,
                netScoreToPar: totalNet - totalPar
            )
        }

        let hasScores = teamScores.contains { $0.totalNetScore > 0 }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            individualMatches: [],
            teamScores: hasScores ? teamScores : []
        )
    }

    // MARK: - Team Best Ball

    /// Calculate team best ball: best net score per hole from each team.
    private static func calculateTeamBestBallRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        let teamScores: [TeamRoundScore] = teams.map { team in
            let teamPlayers = players
                .filter { $0.team?.id == team.id }
                .filter { round.playerIds.contains($0.id) }

            let teamScorecards = teamPlayers.compactMap { round.scorecard(forPlayer: $0.id) }

            var totalBestBall = 0
            var totalBestBallGross = 0
            var totalPar = 0

            for hole in course.holes {
                if let bestNet = ScoringEngine.bestBallScore(
                    teamScorecards: teamScorecards,
                    holeNumber: hole.number
                ) {
                    totalBestBall += bestNet
                    totalPar += hole.par
                }
                let grossScores = teamScorecards.compactMap { card -> Int? in
                    guard let score = card.score(forHole: hole.number), score.isCompleted else { return nil }
                    return score.strokes
                }
                if let bestGross = grossScores.min() {
                    totalBestBallGross += bestGross
                }
            }

            return TeamRoundScore(
                teamId: team.id,
                teamName: team.name,
                teamColor: team.color,
                totalGrossScore: totalBestBallGross,
                totalNetScore: totalBestBall,
                netScoreToPar: totalBestBall - totalPar
            )
        }

        let hasScores = teamScores.contains { $0.totalNetScore > 0 }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            individualMatches: [],
            teamScores: hasScores ? teamScores : []
        )
    }

    // MARK: - Trip-Level Team Standings

    /// Generate trip-level team points standings across all rounds.
    static func generateTeamPointsStandings(trip: Trip) -> [TeamPointsStanding] {
        guard trip.teams.count == 2 else { return [] }

        var roundResults: [RoundTeamMatchResult] = []
        for (index, round) in trip.rounds.enumerated() {
            guard let course = round.course else { continue }
            let rule = resolveScoringRule(round: round, trip: trip)

            var result = calculateRoundResults(
                round: round,
                course: course,
                players: trip.players,
                teams: trip.teams,
                scoringRule: rule
            )
            result.roundLabel = "R\(index + 1): \(course.name)"

            let hasContent = !result.individualMatches.isEmpty || !result.teamScores.isEmpty
            if hasContent {
                roundResults.append(result)
            }
        }

        return trip.teams.map { team in
            var won = 0
            var lost = 0
            var halved = 0
            var totalPoints = 0.0

            for roundResult in roundResults {
                totalPoints += roundResult.pointsForTeam(team.id)

                if roundResult.scoringRule.format.isPerPlayerFormat {
                    for match in roundResult.individualMatches {
                        guard match.matchPlayResult.isComplete else { continue }
                        if let winnerId = match.winningTeamId {
                            if winnerId == team.id { won += 1 } else { lost += 1 }
                        } else if match.isHalved {
                            halved += 1
                        }
                    }
                } else {
                    guard roundResult.teamScores.count == 2 else { continue }
                    let sorted = roundResult.teamScores.sorted { $0.totalNetScore < $1.totalNetScore }
                    if sorted[0].totalNetScore == sorted[1].totalNetScore {
                        halved += 1
                    } else if sorted[0].teamId == team.id {
                        won += 1
                    } else {
                        lost += 1
                    }
                }
            }

            return TeamPointsStanding(
                teamId: team.id,
                teamName: team.name,
                teamColor: team.color,
                totalPoints: totalPoints,
                matchesWon: won,
                matchesLost: lost,
                matchesHalved: halved,
                playerCount: team.playerCount,
                roundResults: roundResults
            )
        }
        .sorted { $0.totalPoints > $1.totalPoints }
    }
}

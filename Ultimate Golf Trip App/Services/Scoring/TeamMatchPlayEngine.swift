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

    // MARK: - Team Pair Generation

    /// Generate all unique team pairings for round-robin competition.
    /// For 4 teams: (A,B), (A,C), (A,D), (B,C), (B,D), (C,D) = 6 pairs.
    static func generateTeamPairs(teams: [Team]) -> [(Team, Team)] {
        var pairs: [(Team, Team)] = []
        for i in 0..<teams.count {
            for j in (i + 1)..<teams.count {
                pairs.append((teams[i], teams[j]))
            }
        }
        return pairs
    }

    // MARK: - Resolve Scoring Rule

    /// Determine the scoring rule for a round.
    /// Priority: round-level rule → course-level rule (legacy) → trip defaults.
    static func resolveScoringRule(round: Round, trip: Trip) -> TeamScoringRule {
        // Round-level rule (set at round creation time — immutable per round)
        if let roundRule = round.teamScoringRule {
            return roundRule
        }
        // Course-level rule (legacy fallback for rounds created before per-round storage)
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
    /// Supports 2 or more teams. Per-player formats generate round-robin pairings
    /// across all team combinations; team-comparison formats compare all teams directly.
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

        guard teams.count >= 2 else { return emptyResult }

        // When nines scoring is enabled, per-player formats use nines calculation;
        // team-comparison formats compute segment scores in addition to totals.
        if scoringRule.effectiveUseNines && scoringRule.format != .ninesAndOverall {
            switch scoringRule.format {
            case .traditionalMatchPlay, .singlesMatchPlay:
                return calculateMatchPlayNinesRound(
                    round: round, course: course, players: players, teams: teams, scoringRule: scoringRule
                )
            case .teamStrokePlay:
                return calculateTeamStrokePlayNinesRound(
                    round: round, course: course, players: players, teams: teams, scoringRule: scoringRule
                )
            case .teamBestBall:
                return calculateTeamBestBallNinesRound(
                    round: round, course: course, players: players, teams: teams, scoringRule: scoringRule
                )
            case .ninesAndOverall:
                break // handled below
            }
        }

        switch scoringRule.format {
        case .traditionalMatchPlay, .singlesMatchPlay:
            return calculateMatchPlayRound(
                round: round,
                course: course,
                players: players,
                teams: teams,
                scoringRule: scoringRule
            )
        case .ninesAndOverall:
            return calculateNinesAndOverallRound(
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
    /// For 2 teams: pairs players 1v1. For N>2 teams: generates round-robin pairings
    /// across every team combination.
    private static func calculateMatchPlayRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        // Determine pairings
        var pairings: [MatchPairing] = []

        if !round.matchPairings.isEmpty {
            pairings = round.matchPairings
        } else {
            // Generate round-robin pairings across all team combinations
            let teamPairs = generateTeamPairs(teams: teams)
            for (teamA, teamB) in teamPairs {
                let teamAPlayers = players
                    .filter { $0.team?.id == teamA.id }
                    .filter { round.playerIds.contains($0.id) }
                let teamBPlayers = players
                    .filter { $0.team?.id == teamB.id }
                    .filter { round.playerIds.contains($0.id) }
                pairings.append(contentsOf: generatePairings(team1Players: teamAPlayers, team2Players: teamBPlayers))
            }
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
                player1TeamId: p1.team?.id ?? p1.id,
                player2TeamId: p2.team?.id ?? p2.id,
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

    // MARK: - Nines & Overall

    /// Calculate nines & overall format: 1v1 net stroke play, scoring front 9, back 9, and overall.
    /// Supports round-robin pairings for N>2 teams.
    private static func calculateNinesAndOverallRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        // Determine pairings (same approach as match play)
        var pairings: [MatchPairing] = []
        if !round.matchPairings.isEmpty {
            pairings = round.matchPairings
        } else {
            let teamPairs = generateTeamPairs(teams: teams)
            for (teamA, teamB) in teamPairs {
                let teamAPlayers = players
                    .filter { $0.team?.id == teamA.id }
                    .filter { round.playerIds.contains($0.id) }
                let teamBPlayers = players
                    .filter { $0.team?.id == teamB.id }
                    .filter { round.playerIds.contains($0.id) }
                pairings.append(contentsOf: generatePairings(team1Players: teamAPlayers, team2Players: teamBPlayers))
            }
        }

        let ninesMatches: [NinesMatchResult] = pairings.compactMap { pairing in
            guard let card1 = round.scorecard(forPlayer: pairing.player1Id),
                  let card2 = round.scorecard(forPlayer: pairing.player2Id),
                  let p1 = players.first(where: { $0.id == pairing.player1Id }),
                  let p2 = players.first(where: { $0.id == pairing.player2Id })
            else { return nil }

            guard card1.holesCompleted > 0 || card2.holesCompleted > 0 else { return nil }

            // Calculate net scores using handicap-adjusted stroke play
            let adjusted1 = ScoringEngine.calculateStrokePlay(scorecard: card1, holes: course.holes)
            let adjusted2 = ScoringEngine.calculateStrokePlay(scorecard: card2, holes: course.holes)

            // Calculate front 9, back 9, and overall net totals
            let front9Scores1 = adjusted1.holeScores.filter { $0.holeNumber <= 9 && $0.isCompleted }
            let front9Scores2 = adjusted2.holeScores.filter { $0.holeNumber <= 9 && $0.isCompleted }
            let back9Scores1 = adjusted1.holeScores.filter { $0.holeNumber > 9 && $0.isCompleted }
            let back9Scores2 = adjusted2.holeScores.filter { $0.holeNumber > 9 && $0.isCompleted }

            let p1Front9Net = front9Scores1.reduce(0) { $0 + $1.netStrokes }
            let p2Front9Net = front9Scores2.reduce(0) { $0 + $1.netStrokes }
            let p1Back9Net = back9Scores1.reduce(0) { $0 + $1.netStrokes }
            let p2Back9Net = back9Scores2.reduce(0) { $0 + $1.netStrokes }
            let p1OverallNet = p1Front9Net + p1Back9Net
            let p2OverallNet = p2Front9Net + p2Back9Net

            let holesCompleted = min(
                front9Scores1.count + back9Scores1.count,
                front9Scores2.count + back9Scores2.count
            )

            return NinesMatchResult(
                player1Id: p1.id,
                player2Id: p2.id,
                player1Name: p1.name,
                player2Name: p2.name,
                player1TeamId: p1.team?.id ?? p1.id,
                player2TeamId: p2.team?.id ?? p2.id,
                player1Front9Net: p1Front9Net,
                player2Front9Net: p2Front9Net,
                player1Back9Net: p1Back9Net,
                player2Back9Net: p2Back9Net,
                player1OverallNet: p1OverallNet,
                player2OverallNet: p2OverallNet,
                holesCompleted: holesCompleted,
                totalHoles: course.holes.count
            )
        }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            ninesMatches: ninesMatches
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

    // MARK: - Team Best Ball (4-Ball Match Play)

    /// Calculate 4-ball best ball match play: each team's lowest net score per hole
    /// wins that hole (match play). Uses 90% handicap allowance with lowest-plays-scratch.
    /// Generates round-robin team matchups for N≥2 teams.
    private static func calculateTeamBestBallRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        let teamPairs = generateTeamPairs(teams: teams)
        let totalHoles = course.holes.count

        var bestBallMatches: [TeamBestBallMatchResult] = []

        for (teamA, teamB) in teamPairs {
            let teamAPlayers = players
                .filter { $0.team?.id == teamA.id }
                .filter { round.playerIds.contains($0.id) }
            let teamBPlayers = players
                .filter { $0.team?.id == teamB.id }
                .filter { round.playerIds.contains($0.id) }

            let allPlayers = teamAPlayers + teamBPlayers
            guard !allPlayers.isEmpty else { continue }

            // Step 1: Get course handicaps and apply 90% allowance
            let adjustedHandicaps: [(Player, Int)] = allPlayers.map { player in
                let courseHcap = round.scorecard(forPlayer: player.id)?.courseHandicap ?? 0
                let adjusted = HandicapEngine.bestBallHandicap(courseHandicap: courseHcap, allowancePercentage: 0.9)
                return (player, adjusted)
            }

            // Step 2: Lowest plays scratch — subtract the minimum from everyone
            let lowestAdj = adjustedHandicaps.map(\.1).min() ?? 0
            let strokesByPlayer: [UUID: [Int: Int]] = Dictionary(uniqueKeysWithValues:
                adjustedHandicaps.map { (player, adj) in
                    let netStrokes = adj - lowestAdj
                    let strokeMap = HandicapEngine.distributeStrokes(courseHandicap: netStrokes, holes: course.holes)
                    return (player.id, strokeMap)
                }
            )

            // Step 3: Play each hole — best net from each team, match play scoring
            var team1Wins = 0
            var team2Wins = 0
            var holesPlayed = 0

            for hole in course.holes {
                // Get best net for Team A
                let teamANets: [Int] = teamAPlayers.compactMap { player in
                    guard let card = round.scorecard(forPlayer: player.id),
                          let score = card.score(forHole: hole.number),
                          score.isCompleted else { return nil }
                    let strokes = strokesByPlayer[player.id]?[hole.number] ?? 0
                    return score.strokes - strokes
                }

                let teamBNets: [Int] = teamBPlayers.compactMap { player in
                    guard let card = round.scorecard(forPlayer: player.id),
                          let score = card.score(forHole: hole.number),
                          score.isCompleted else { return nil }
                    let strokes = strokesByPlayer[player.id]?[hole.number] ?? 0
                    return score.strokes - strokes
                }

                guard let bestA = teamANets.min(), let bestB = teamBNets.min() else { continue }

                holesPlayed += 1

                if bestA < bestB {
                    team1Wins += 1
                } else if bestB < bestA {
                    team2Wins += 1
                }

                // Early termination: if margin exceeds remaining holes
                let margin = abs(team1Wins - team2Wins)
                let remaining = totalHoles - holesPlayed
                if margin > remaining { break }
            }

            bestBallMatches.append(TeamBestBallMatchResult(
                team1Id: teamA.id,
                team2Id: teamB.id,
                team1Name: teamA.name,
                team2Name: teamB.name,
                team1Color: teamA.color,
                team2Color: teamB.color,
                team1HolesWon: team1Wins,
                team2HolesWon: team2Wins,
                holesPlayed: holesPlayed,
                totalHoles: totalHoles
            ))
        }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            bestBallMatches: bestBallMatches
        )
    }

    // MARK: - Match Play with Nines (Traditional & Singles)

    /// Calculate match play with F9/B9/OA scoring.
    /// For each 1v1 pairing, compare net strokes per segment (front 9, back 9, overall).
    /// Produces NinesMatchResult entries so the existing nines point logic handles scoring.
    private static func calculateMatchPlayNinesRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        // Determine pairings (same approach as regular match play)
        var pairings: [MatchPairing] = []
        if !round.matchPairings.isEmpty {
            pairings = round.matchPairings
        } else {
            let teamPairs = generateTeamPairs(teams: teams)
            for (teamA, teamB) in teamPairs {
                let teamAPlayers = players.filter { $0.team?.id == teamA.id }.filter { round.playerIds.contains($0.id) }
                let teamBPlayers = players.filter { $0.team?.id == teamB.id }.filter { round.playerIds.contains($0.id) }
                pairings.append(contentsOf: generatePairings(team1Players: teamAPlayers, team2Players: teamBPlayers))
            }
        }

        // Reuse the same net stroke comparison as ninesAndOverall
        let ninesMatches: [NinesMatchResult] = pairings.compactMap { pairing in
            guard let card1 = round.scorecard(forPlayer: pairing.player1Id),
                  let card2 = round.scorecard(forPlayer: pairing.player2Id),
                  let p1 = players.first(where: { $0.id == pairing.player1Id }),
                  let p2 = players.first(where: { $0.id == pairing.player2Id })
            else { return nil }
            guard card1.holesCompleted > 0 || card2.holesCompleted > 0 else { return nil }

            let adjusted1 = ScoringEngine.calculateStrokePlay(scorecard: card1, holes: course.holes)
            let adjusted2 = ScoringEngine.calculateStrokePlay(scorecard: card2, holes: course.holes)

            let front9Scores1 = adjusted1.holeScores.filter { $0.holeNumber <= 9 && $0.isCompleted }
            let front9Scores2 = adjusted2.holeScores.filter { $0.holeNumber <= 9 && $0.isCompleted }
            let back9Scores1 = adjusted1.holeScores.filter { $0.holeNumber > 9 && $0.isCompleted }
            let back9Scores2 = adjusted2.holeScores.filter { $0.holeNumber > 9 && $0.isCompleted }

            let p1Front9Net = front9Scores1.reduce(0) { $0 + $1.netStrokes }
            let p2Front9Net = front9Scores2.reduce(0) { $0 + $1.netStrokes }
            let p1Back9Net = back9Scores1.reduce(0) { $0 + $1.netStrokes }
            let p2Back9Net = back9Scores2.reduce(0) { $0 + $1.netStrokes }

            let holesCompleted = min(
                front9Scores1.count + back9Scores1.count,
                front9Scores2.count + back9Scores2.count
            )

            return NinesMatchResult(
                player1Id: p1.id,
                player2Id: p2.id,
                player1Name: p1.name,
                player2Name: p2.name,
                player1TeamId: p1.team?.id ?? p1.id,
                player2TeamId: p2.team?.id ?? p2.id,
                player1Front9Net: p1Front9Net,
                player2Front9Net: p2Front9Net,
                player1Back9Net: p1Back9Net,
                player2Back9Net: p2Back9Net,
                player1OverallNet: p1Front9Net + p1Back9Net,
                player2OverallNet: p2Front9Net + p2Back9Net,
                holesCompleted: holesCompleted,
                totalHoles: course.holes.count
            )
        }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            ninesMatches: ninesMatches
        )
    }

    // MARK: - Team Stroke Play with Nines

    /// Calculate team stroke play with F9/B9/OA scoring.
    /// Computes team net totals for each segment, then uses TeamNinesScore for pairwise comparison.
    private static func calculateTeamStrokePlayNinesRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        let teamNinesScores: [TeamNinesScore] = teams.map { team in
            let teamPlayers = players
                .filter { $0.team?.id == team.id }
                .filter { round.playerIds.contains($0.id) }

            var f9Net = 0, b9Net = 0

            for player in teamPlayers {
                guard let card = round.scorecard(forPlayer: player.id) else { continue }
                let processed = ScoringEngine.calculateStrokePlay(scorecard: card, holes: course.holes)
                let front9 = processed.holeScores.filter { $0.holeNumber <= 9 && $0.isCompleted }
                let back9 = processed.holeScores.filter { $0.holeNumber > 9 && $0.isCompleted }
                f9Net += front9.reduce(0) { $0 + $1.netStrokes }
                b9Net += back9.reduce(0) { $0 + $1.netStrokes }
            }

            return TeamNinesScore(
                teamId: team.id, teamName: team.name, teamColor: team.color,
                front9Net: f9Net, back9Net: b9Net, overallNet: f9Net + b9Net
            )
        }

        let hasScores = teamNinesScores.contains { $0.overallNet > 0 }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            teamNinesScores: hasScores ? teamNinesScores : []
        )
    }

    // MARK: - Team Best Ball with Nines

    /// Calculate team best ball with F9/B9/OA scoring using 4-ball handicap rules.
    /// Computes best-ball per hole with 90% allowance / lowest-plays-scratch,
    /// then splits into F9/B9/Overall segments for points.
    private static func calculateTeamBestBallNinesRound(
        round: Round,
        course: Course,
        players: [Player],
        teams: [Team],
        scoringRule: TeamScoringRule
    ) -> RoundTeamMatchResult {
        let teamNinesScores: [TeamNinesScore] = teams.map { team in
            let teamPlayers = players
                .filter { $0.team?.id == team.id }
                .filter { round.playerIds.contains($0.id) }

            // Apply 90% allowance + lowest-plays-scratch across ALL players in the round
            let allRoundPlayers = players.filter { round.playerIds.contains($0.id) }
            let allAdjusted = allRoundPlayers.map { p in
                HandicapEngine.bestBallHandicap(
                    courseHandicap: round.scorecard(forPlayer: p.id)?.courseHandicap ?? 0,
                    allowancePercentage: 0.9
                )
            }
            let lowestAdj = allAdjusted.min() ?? 0

            var f9Net = 0, b9Net = 0

            for hole in course.holes {
                let nets: [Int] = teamPlayers.compactMap { player in
                    guard let card = round.scorecard(forPlayer: player.id),
                          let score = card.score(forHole: hole.number),
                          score.isCompleted else { return nil }
                    let adj = HandicapEngine.bestBallHandicap(
                        courseHandicap: card.courseHandicap, allowancePercentage: 0.9
                    )
                    let netStrokes = adj - lowestAdj
                    let strokeMap = HandicapEngine.distributeStrokes(courseHandicap: netStrokes, holes: course.holes)
                    return score.strokes - (strokeMap[hole.number] ?? 0)
                }
                guard let bestNet = nets.min() else { continue }
                if hole.number <= 9 {
                    f9Net += bestNet
                } else {
                    b9Net += bestNet
                }
            }

            return TeamNinesScore(
                teamId: team.id, teamName: team.name, teamColor: team.color,
                front9Net: f9Net, back9Net: b9Net, overallNet: f9Net + b9Net
            )
        }

        let hasScores = teamNinesScores.contains { $0.overallNet > 0 }

        return RoundTeamMatchResult(
            id: round.id,
            roundLabel: course.name,
            courseName: course.name,
            scoringRule: scoringRule,
            teamNinesScores: hasScores ? teamNinesScores : []
        )
    }

    // MARK: - Trip-Level Team Standings

    /// Generate trip-level team points standings across all rounds.
    /// Supports 2 or more teams. For per-player formats, matches from all team
    /// combinations are included. For team-comparison formats, each team is
    /// ranked against all others per round.
    static func generateTeamPointsStandings(trip: Trip) -> [TeamPointsStanding] {
        guard trip.teams.count >= 2 else { return [] }

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

            let hasContent = !result.individualMatches.isEmpty || !result.ninesMatches.isEmpty || !result.teamScores.isEmpty || !result.teamNinesScores.isEmpty || !result.bestBallMatches.isEmpty
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

                if roundResult.scoringRule.effectiveUseNines && roundResult.scoringRule.format.isPerPlayerFormat {
                    // Count segment wins for per-player nines formats (ninesAndOverall, match play with nines)
                    for match in roundResult.ninesMatches {
                        guard match.player1TeamId == team.id || match.player2TeamId == team.id else { continue }
                        // Front 9
                        if let winner = match.front9WinnerTeamId {
                            if winner == team.id { won += 1 } else { lost += 1 }
                        } else if match.front9Halved { halved += 1 }
                        // Back 9
                        if let winner = match.back9WinnerTeamId {
                            if winner == team.id { won += 1 } else { lost += 1 }
                        } else if match.back9Halved { halved += 1 }
                        // Overall
                        if let winner = match.overallWinnerTeamId {
                            if winner == team.id { won += 1 } else { lost += 1 }
                        } else if match.overallHalved { halved += 1 }
                    }
                } else if roundResult.scoringRule.effectiveUseNines && !roundResult.scoringRule.format.isPerPlayerFormat {
                    // Team-comparison formats with nines: count segment wins vs each other team
                    guard roundResult.teamNinesScores.count >= 2,
                          let myScore = roundResult.teamNinesScores.first(where: { $0.teamId == team.id }) else { continue }
                    for otherScore in roundResult.teamNinesScores where otherScore.teamId != team.id {
                        // F9
                        if myScore.front9Net < otherScore.front9Net { won += 1 }
                        else if myScore.front9Net > otherScore.front9Net { lost += 1 }
                        else { halved += 1 }
                        // B9
                        if myScore.back9Net < otherScore.back9Net { won += 1 }
                        else if myScore.back9Net > otherScore.back9Net { lost += 1 }
                        else { halved += 1 }
                        // Overall
                        if myScore.overallNet < otherScore.overallNet { won += 1 }
                        else if myScore.overallNet > otherScore.overallNet { lost += 1 }
                        else { halved += 1 }
                    }
                } else if roundResult.scoringRule.format.isPerPlayerFormat {
                    // Count match wins (only for matches involving this team)
                    for match in roundResult.individualMatches {
                        guard match.player1TeamId == team.id || match.player2TeamId == team.id else { continue }
                        guard match.matchPlayResult.isComplete else { continue }
                        if let winnerId = match.winningTeamId {
                            if winnerId == team.id { won += 1 } else { lost += 1 }
                        } else if match.isHalved {
                            halved += 1
                        }
                    }
                } else if !roundResult.bestBallMatches.isEmpty {
                    // 4-ball best ball match play
                    for match in roundResult.bestBallMatches {
                        guard match.team1Id == team.id || match.team2Id == team.id else { continue }
                        guard match.isComplete else { continue }
                        if let winnerId = match.winningTeamId {
                            if winnerId == team.id { won += 1 } else { lost += 1 }
                        } else if match.isHalved {
                            halved += 1
                        }
                    }
                } else {
                    // Team stroke play: rank among all teams
                    guard roundResult.teamScores.count >= 2 else { continue }
                    let myScore = roundResult.teamScores.first { $0.teamId == team.id }
                    guard let myScore else { continue }

                    // Count wins/losses against each other team
                    for otherScore in roundResult.teamScores where otherScore.teamId != team.id {
                        if myScore.totalNetScore < otherScore.totalNetScore {
                            won += 1
                        } else if myScore.totalNetScore > otherScore.totalNetScore {
                            lost += 1
                        } else {
                            halved += 1
                        }
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

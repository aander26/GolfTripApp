import Foundation

struct LeaderboardEngine {

    /// Generate leaderboard entries for a trip across all rounds
    static func generateLeaderboard(trip: Trip) -> [LeaderboardEntry] {
        var entries: [UUID: LeaderboardEntry] = [:]

        // Initialize entries for all players
        for player in trip.players {
            entries[player.id] = LeaderboardEntry(
                playerId: player.id,
                playerName: player.name,
                teamId: player.teamId,
                totalRounds: trip.rounds.filter { $0.playerIds.contains(player.id) }.count
            )
        }

        // Accumulate scores from all rounds
        for round in trip.rounds {
            guard let course = round.course else { continue }
            let processed = ScoringEngine.processRound(round: round, course: course)

            for scorecard in processed.scorecards {
                guard var entry = entries[scorecard.playerId] else { continue }

                let grossToPar = ScoringEngine.scoreToPar(scorecard: scorecard)
                let netToPar = ScoringEngine.netScoreToPar(scorecard: scorecard)

                entry.totalGross += scorecard.totalGross
                entry.totalNet += scorecard.totalNet
                entry.scoreToPar += grossToPar
                entry.netScoreToPar += netToPar
                entry.holesCompleted += scorecard.holesCompleted

                if scorecard.isComplete {
                    entry.roundsCompleted += 1
                }

                // Stableford points
                if round.format == .stableford {
                    entry.stablefordPoints += ScoringEngine.calculateStablefordTotal(
                        scorecard: round.scorecards.first { $0.player?.id == scorecard.playerId }!,
                        holes: course.holes
                    )
                }

                entries[scorecard.playerId] = entry
            }
        }

        // Sort and assign positions
        var sorted = Array(entries.values).sorted { a, b in
            if a.netScoreToPar != b.netScoreToPar {
                return a.netScoreToPar < b.netScoreToPar
            }
            return a.scoreToPar < b.scoreToPar
        }

        assignPositions(&sorted)
        return sorted
    }

    /// Generate leaderboard for a single round
    static func generateRoundLeaderboard(round: Round, course: Course, players: [Player]) -> [LeaderboardEntry] {
        let processed = ScoringEngine.processRound(round: round, course: course)

        var entries: [LeaderboardEntry] = processed.scorecards.compactMap { scorecard in
            guard let player = players.first(where: { $0.id == scorecard.playerId }) else { return nil }

            let grossToPar = ScoringEngine.scoreToPar(scorecard: scorecard)
            let netToPar = ScoringEngine.netScoreToPar(scorecard: scorecard)

            return LeaderboardEntry(
                playerId: player.id,
                playerName: player.name,
                teamId: player.teamId,
                totalGross: scorecard.totalGross,
                totalNet: scorecard.totalNet,
                scoreToPar: grossToPar,
                netScoreToPar: netToPar,
                holesCompleted: scorecard.holesCompleted,
                roundsCompleted: scorecard.isComplete ? 1 : 0,
                totalRounds: 1,
                stablefordPoints: round.format == .stableford
                    ? ScoringEngine.calculateStablefordTotal(
                        scorecard: round.scorecards.first { $0.player?.id == scorecard.playerId }!,
                        holes: course.holes
                    )
                    : 0
            )
        }

        switch round.format {
        case .stableford:
            entries.sort { $0.stablefordPoints > $1.stablefordPoints }
        default:
            entries.sort { a, b in
                if a.netScoreToPar != b.netScoreToPar {
                    return a.netScoreToPar < b.netScoreToPar
                }
                return a.scoreToPar < b.scoreToPar
            }
        }

        assignPositions(&entries)
        return entries
    }

    /// Generate Stableford leaderboard (sorted by points descending)
    static func generateStablefordLeaderboard(trip: Trip) -> [LeaderboardEntry] {
        var entries = generateLeaderboard(trip: trip)
        entries.sort { $0.stablefordPoints > $1.stablefordPoints }
        assignPositions(&entries)
        return entries
    }

    /// Assign positions with tie handling
    private static func assignPositions(_ entries: inout [LeaderboardEntry]) {
        guard !entries.isEmpty else { return }

        var position = 1
        entries[0].position = position

        for i in 1..<entries.count {
            let isTied = entries[i].netScoreToPar == entries[i - 1].netScoreToPar &&
                         entries[i].scoreToPar == entries[i - 1].scoreToPar
            if !isTied {
                position = i + 1
            }
            entries[i].position = position
        }
    }

    /// Get team standings by aggregating player scores per team
    static func generateTeamLeaderboard(trip: Trip) -> [(team: Team, totalNet: Int, netToPar: Int)] {
        let playerLeaderboard = generateLeaderboard(trip: trip)

        var teamScores: [(team: Team, totalNet: Int, netToPar: Int)] = trip.teams.map { team in
            let teamEntries = playerLeaderboard.filter { $0.teamId == team.id }
            let totalNet = teamEntries.reduce(0) { $0 + $1.totalNet }
            let netToPar = teamEntries.reduce(0) { $0 + $1.netScoreToPar }
            return (team: team, totalNet: totalNet, netToPar: netToPar)
        }

        teamScores.sort { $0.netToPar < $1.netToPar }
        return teamScores
    }
}

import Foundation

/// One team-vs-team head-to-head record aggregated across every round in the trip where
/// the two teams faced each other (via individual / singles match play or 4-ball best ball).
struct TeamMatchupRecord: Identifiable, Hashable {
    /// `<team1.id>-<team2.id>` (sorted) so the record is stable across renders.
    let id: String
    let team1Id: UUID
    let team2Id: UUID
    let team1Name: String
    let team2Name: String
    /// Counts of matches won / lost / halved by team 1 against team 2 across the trip.
    let team1Wins: Int
    let team2Wins: Int
    let halves: Int

    /// "BLUE 3-1-1 vs RED" — for compact display.
    var compactLine: String {
        "\(team1Name.uppercased()) \(team1Wins)-\(team2Wins)-\(halves) vs \(team2Name.uppercased())"
    }

    /// True when team 1 leads the series (more wins).
    var team1Leads: Bool { team1Wins > team2Wins }
    /// True when the series is currently tied.
    var isTied: Bool { team1Wins == team2Wins }
}

/// Aggregates team-vs-team matchup outcomes across a trip's rounds. Counts wins from both
/// per-player individual matches (singles / traditional match play) and 4-ball best ball
/// team matches. Skips rounds whose format doesn't produce per-pair results.
enum TeamMatchupHistory {
    static func aggregate(trip: Trip) -> [TeamMatchupRecord] {
        guard trip.teams.count >= 2 else { return [] }

        // Iterate every unordered team pair.
        var records: [String: (team1Wins: Int, team2Wins: Int, halves: Int)] = [:]

        for round in trip.rounds {
            guard let course = round.course else { continue }
            let rule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
            let result = TeamMatchPlayEngine.calculateRoundResults(
                round: round,
                course: course,
                players: trip.players,
                teams: trip.teams,
                scoringRule: rule
            )

            // Individual / singles match play.
            for match in result.individualMatches where match.matchPlayResult.isComplete {
                let teamA = match.player1TeamId
                let teamB = match.player2TeamId
                guard teamA != teamB else { continue }
                let key = pairKey(teamA, teamB)
                let team1IsCanonical = teamA.uuidString < teamB.uuidString
                var rec = records[key] ?? (0, 0, 0)
                if match.isHalved {
                    rec.halves += 1
                } else if let winnerTeam = match.winningTeamId {
                    if (winnerTeam == teamA && team1IsCanonical) ||
                       (winnerTeam == teamB && !team1IsCanonical) {
                        rec.team1Wins += 1
                    } else {
                        rec.team2Wins += 1
                    }
                }
                records[key] = rec
            }

            // 4-ball best ball.
            for match in result.bestBallMatches where match.isComplete {
                let teamA = match.team1Id
                let teamB = match.team2Id
                guard teamA != teamB else { continue }
                let key = pairKey(teamA, teamB)
                let team1IsCanonical = teamA.uuidString < teamB.uuidString
                var rec = records[key] ?? (0, 0, 0)
                if match.isHalved {
                    rec.halves += 1
                } else if let winnerTeam = match.winningTeamId {
                    if (winnerTeam == teamA && team1IsCanonical) ||
                       (winnerTeam == teamB && !team1IsCanonical) {
                        rec.team1Wins += 1
                    } else {
                        rec.team2Wins += 1
                    }
                }
                records[key] = rec
            }
        }

        return records.compactMap { (key, counts) -> TeamMatchupRecord? in
            let parts = key.split(separator: "-")
            guard parts.count == 2,
                  let id1 = UUID(uuidString: String(parts[0])),
                  let id2 = UUID(uuidString: String(parts[1])),
                  let team1 = trip.teams.first(where: { $0.id == id1 }),
                  let team2 = trip.teams.first(where: { $0.id == id2 }) else { return nil }
            return TeamMatchupRecord(
                id: key,
                team1Id: id1,
                team2Id: id2,
                team1Name: team1.name,
                team2Name: team2.name,
                team1Wins: counts.team1Wins,
                team2Wins: counts.team2Wins,
                halves: counts.halves
            )
        }
        // Sort by total matches played descending, then by team1 name for stability.
        .sorted { lhs, rhs in
            let lhsTotal = lhs.team1Wins + lhs.team2Wins + lhs.halves
            let rhsTotal = rhs.team1Wins + rhs.team2Wins + rhs.halves
            if lhsTotal != rhsTotal { return lhsTotal > rhsTotal }
            return lhs.team1Name < rhs.team1Name
        }
    }

    /// Deterministic key: smaller UUID first so (A, B) and (B, A) collapse to the same record.
    private static func pairKey(_ a: UUID, _ b: UUID) -> String {
        let sorted = [a.uuidString, b.uuidString].sorted()
        return "\(sorted[0])-\(sorted[1])"
    }
}

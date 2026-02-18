import Foundation

// MARK: - Individual Match Result

/// Result of a single 1v1 match within the team competition.
/// Computed on-the-fly (not persisted) — wraps MatchPlayResult with team context.
struct IndividualMatchResult: Identifiable, Hashable {
    var id: UUID { matchPlayResult.id }
    var player1Id: UUID
    var player2Id: UUID
    var player1Name: String
    var player2Name: String
    var player1TeamId: UUID
    var player2TeamId: UUID
    var matchPlayResult: MatchPlayResult

    /// Which team won this individual match (nil if halved or incomplete)
    var winningTeamId: UUID? {
        guard matchPlayResult.isComplete else { return nil }
        if matchPlayResult.player1Wins > matchPlayResult.player2Wins {
            return player1TeamId
        } else if matchPlayResult.player2Wins > matchPlayResult.player1Wins {
            return player2TeamId
        }
        return nil
    }

    /// True if the match is complete and tied
    var isHalved: Bool {
        matchPlayResult.isComplete && matchPlayResult.player1Wins == matchPlayResult.player2Wins
    }

    /// True if the match is still in progress
    var isInProgress: Bool {
        !matchPlayResult.isComplete
    }

    /// Human-readable result string, e.g., "Alex def. Keith 3&2"
    var displayText: String {
        let p1Wins = matchPlayResult.player1Wins
        let p2Wins = matchPlayResult.player2Wins

        if !matchPlayResult.isComplete {
            if p1Wins == p2Wins {
                return "\(player1Name) vs \(player2Name) — All Square thru \(matchPlayResult.holesPlayed)"
            }
            let leader = p1Wins > p2Wins ? player1Name : player2Name
            let margin = abs(p1Wins - p2Wins)
            return "\(leader) \(margin) UP thru \(matchPlayResult.holesPlayed)"
        }

        if p1Wins == p2Wins {
            return "\(player1Name) vs \(player2Name) — Halved"
        }

        let winner = p1Wins > p2Wins ? player1Name : player2Name
        let loser = p1Wins > p2Wins ? player2Name : player1Name
        let margin = abs(p1Wins - p2Wins)
        let remaining = matchPlayResult.holesRemaining

        if remaining == 0 {
            return "\(winner) def. \(loser) \(margin) UP"
        } else {
            return "\(winner) def. \(loser) \(margin)&\(remaining)"
        }
    }

    /// Display text for singles match play (hole-by-hole points)
    var singlesDisplayText: String {
        let p1Wins = matchPlayResult.player1Wins
        let p2Wins = matchPlayResult.player2Wins
        if p1Wins == p2Wins {
            return "\(player1Name) vs \(player2Name) — Tied \(p1Wins)-\(p2Wins)"
        }
        let winner = p1Wins > p2Wins ? player1Name : player2Name
        let loser = p1Wins > p2Wins ? player2Name : player1Name
        let winnerHoles = max(p1Wins, p2Wins)
        let loserHoles = min(p1Wins, p2Wins)
        return "\(winner) \(winnerHoles)-\(loserHoles) over \(loser)"
    }

    /// The winning player's name (nil if halved or in progress)
    var winnerName: String? {
        guard matchPlayResult.isComplete else { return nil }
        if matchPlayResult.player1Wins > matchPlayResult.player2Wins {
            return player1Name
        } else if matchPlayResult.player2Wins > matchPlayResult.player1Wins {
            return player2Name
        }
        return nil
    }
}

// MARK: - Team Round Score (for stroke play / best ball)

/// A team's aggregate score for a single round (stroke play or best ball).
struct TeamRoundScore: Identifiable, Hashable {
    var id: UUID { teamId }
    var teamId: UUID
    var teamName: String
    var teamColor: TeamColor
    var totalGrossScore: Int
    var totalNetScore: Int
    var netScoreToPar: Int
}

// MARK: - Round Team Match Result

/// Aggregate team results for a single round — supports all scoring formats.
struct RoundTeamMatchResult: Identifiable {
    var id: UUID  // the round's ID
    var roundLabel: String  // e.g., "R1: Pine Valley"
    var courseName: String
    var scoringRule: TeamScoringRule
    var individualMatches: [IndividualMatchResult]  // for match play formats
    var teamScores: [TeamRoundScore]  // for stroke play / best ball formats

    /// Calculate total points earned by a team in this round, respecting the scoring format.
    func pointsForTeam(_ teamId: UUID) -> Double {
        switch scoringRule.format {
        case .traditionalMatchPlay:
            return traditionalMatchPlayPoints(teamId: teamId)
        case .singlesMatchPlay:
            return singlesMatchPlayPoints(teamId: teamId)
        case .teamStrokePlay, .teamBestBall:
            return teamComparisonPoints(teamId: teamId)
        }
    }

    /// Traditional: win/halve/loss per match
    private func traditionalMatchPlayPoints(teamId: UUID) -> Double {
        var points = 0.0
        for match in individualMatches {
            guard match.matchPlayResult.isComplete else { continue }
            if let winnerId = match.winningTeamId {
                points += winnerId == teamId ? scoringRule.pointsPerWin : scoringRule.pointsPerLoss
            } else if match.isHalved {
                points += scoringRule.pointsPerHalve
            }
        }
        return points
    }

    /// Singles: points per hole won
    private func singlesMatchPlayPoints(teamId: UUID) -> Double {
        var totalHolesWon = 0
        for match in individualMatches {
            if match.player1TeamId == teamId {
                totalHolesWon += match.matchPlayResult.player1Wins
            } else if match.player2TeamId == teamId {
                totalHolesWon += match.matchPlayResult.player2Wins
            }
        }
        return Double(totalHolesWon) * scoringRule.pointsPerWin
    }

    /// Stroke play / best ball: compare team totals, winner gets points
    private func teamComparisonPoints(teamId: UUID) -> Double {
        guard teamScores.count == 2 else { return 0 }
        let sorted = teamScores.sorted { $0.totalNetScore < $1.totalNetScore }
        if sorted[0].totalNetScore == sorted[1].totalNetScore {
            return scoringRule.pointsPerHalve
        }
        return sorted[0].teamId == teamId ? scoringRule.pointsPerWin : scoringRule.pointsPerLoss
    }

    /// The winning team ID for team-comparison formats (stroke play / best ball), nil if tied or no scores
    var winningTeamId: UUID? {
        guard teamScores.count == 2 else { return nil }
        let sorted = teamScores.sorted { $0.totalNetScore < $1.totalNetScore }
        if sorted[0].totalNetScore == sorted[1].totalNetScore { return nil }
        return sorted[0].teamId
    }

    /// Number of completed matches in this round
    var completedMatchCount: Int {
        individualMatches.filter { $0.matchPlayResult.isComplete }.count
    }

    /// Summary text for the round format
    var formatLabel: String {
        scoringRule.format.shortName
    }
}

// MARK: - Trip-Level Team Standings

/// Trip-level team points standing
struct TeamPointsStanding: Identifiable {
    var id: UUID { teamId }
    var teamId: UUID
    var teamName: String
    var teamColor: TeamColor
    var totalPoints: Double
    var matchesWon: Int
    var matchesLost: Int
    var matchesHalved: Int
    var playerCount: Int
    var roundResults: [RoundTeamMatchResult]

    /// Total individual matches played across all rounds
    var totalMatchesPlayed: Int {
        matchesWon + matchesLost + matchesHalved
    }

    /// Record display, e.g., "3W - 1L - 1H"
    var recordDisplay: String {
        "\(matchesWon)W - \(matchesLost)L - \(matchesHalved)H"
    }
}

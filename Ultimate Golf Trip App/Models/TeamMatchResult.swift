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

// MARK: - Nines & Overall Match Result

/// Result of a single 1v1 match in the "Nines & Overall" format.
/// Tracks who won the front 9, back 9, and overall 18 by net stroke play.
struct NinesMatchResult: Identifiable, Hashable {
    var id = UUID()
    var player1Id: UUID
    var player2Id: UUID
    var player1Name: String
    var player2Name: String
    var player1TeamId: UUID
    var player2TeamId: UUID

    /// Net scores for each segment
    var player1Front9Net: Int
    var player2Front9Net: Int
    var player1Back9Net: Int
    var player2Back9Net: Int
    var player1OverallNet: Int
    var player2OverallNet: Int

    /// Number of holes completed
    var holesCompleted: Int

    /// Total holes on the course (defaults to 18 for backward compatibility)
    var totalHoles: Int = 18

    var isComplete: Bool { holesCompleted >= totalHoles }
    var front9Complete: Bool { holesCompleted >= min(9, totalHoles) }

    /// Winner of front 9 (nil if tied)
    var front9WinnerTeamId: UUID? {
        guard front9Complete else { return nil }
        if player1Front9Net < player2Front9Net { return player1TeamId }
        if player2Front9Net < player1Front9Net { return player2TeamId }
        return nil
    }

    /// Winner of back 9 (nil if tied)
    var back9WinnerTeamId: UUID? {
        guard isComplete else { return nil }
        if player1Back9Net < player2Back9Net { return player1TeamId }
        if player2Back9Net < player1Back9Net { return player2TeamId }
        return nil
    }

    /// Winner of overall 18 (nil if tied)
    var overallWinnerTeamId: UUID? {
        guard isComplete else { return nil }
        if player1OverallNet < player2OverallNet { return player1TeamId }
        if player2OverallNet < player1OverallNet { return player2TeamId }
        return nil
    }

    var front9Halved: Bool { front9Complete && player1Front9Net == player2Front9Net }
    var back9Halved: Bool { isComplete && player1Back9Net == player2Back9Net }
    var overallHalved: Bool { isComplete && player1OverallNet == player2OverallNet }

    /// Display text showing segment results
    var displayText: String {
        guard front9Complete else {
            return "\(player1Name) vs \(player2Name) — In Progress"
        }

        var parts: [String] = []

        // Front 9
        if let winner = front9WinnerTeamId {
            let name = winner == player1TeamId ? player1Name : player2Name
            parts.append("F9: \(name)")
        } else {
            parts.append("F9: Halved")
        }

        if isComplete {
            // Back 9
            if let winner = back9WinnerTeamId {
                let name = winner == player1TeamId ? player1Name : player2Name
                parts.append("B9: \(name)")
            } else {
                parts.append("B9: Halved")
            }

            // Overall
            if let winner = overallWinnerTeamId {
                let name = winner == player1TeamId ? player1Name : player2Name
                parts.append("OA: \(name)")
            } else {
                parts.append("OA: Halved")
            }
        } else {
            parts.append("B9: In Progress")
        }

        return parts.joined(separator: " · ")
    }
}

// MARK: - Team Nines Score (for team-comparison formats with F9/B9/OA)

/// A team's segment scores for F9/B9/Overall, used when `useNinesAndOverall` is
/// enabled on team-comparison formats (stroke play, best ball).
struct TeamNinesScore: Identifiable, Hashable {
    var id: UUID { teamId }
    var teamId: UUID
    var teamName: String
    var teamColor: TeamColor
    var front9Net: Int
    var back9Net: Int
    var overallNet: Int
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
    var ninesMatches: [NinesMatchResult]  // for nines & overall format + match play with nines
    var teamScores: [TeamRoundScore]  // for stroke play / best ball formats
    var teamNinesScores: [TeamNinesScore]  // for stroke play / best ball with F9/B9/OA

    init(id: UUID, roundLabel: String, courseName: String, scoringRule: TeamScoringRule,
         individualMatches: [IndividualMatchResult] = [],
         ninesMatches: [NinesMatchResult] = [],
         teamScores: [TeamRoundScore] = [],
         teamNinesScores: [TeamNinesScore] = []) {
        self.id = id
        self.roundLabel = roundLabel
        self.courseName = courseName
        self.scoringRule = scoringRule
        self.individualMatches = individualMatches
        self.ninesMatches = ninesMatches
        self.teamScores = teamScores
        self.teamNinesScores = teamNinesScores
    }

    /// Calculate total points earned by a team in this round, respecting the scoring format.
    func pointsForTeam(_ teamId: UUID) -> Double {
        if scoringRule.effectiveUseNines {
            if scoringRule.format.isPerPlayerFormat {
                // Per-player formats (match play, singles, ninesAndOverall): use ninesMatches
                return ninesAndOverallPoints(teamId: teamId)
            } else {
                // Team-comparison formats (stroke play, best ball) with nines toggle: use teamNinesScores
                return teamComparisonNinesPoints(teamId: teamId)
            }
        }

        switch scoringRule.format {
        case .traditionalMatchPlay:
            return traditionalMatchPlayPoints(teamId: teamId)
        case .singlesMatchPlay:
            return singlesMatchPlayPoints(teamId: teamId)
        case .ninesAndOverall:
            return ninesAndOverallPoints(teamId: teamId)
        case .teamStrokePlay, .teamBestBall:
            return teamComparisonPoints(teamId: teamId)
        }
    }

    /// Traditional: win/halve/loss per match (only matches involving this team)
    private func traditionalMatchPlayPoints(teamId: UUID) -> Double {
        var points = 0.0
        for match in individualMatches {
            guard match.player1TeamId == teamId || match.player2TeamId == teamId else { continue }
            guard match.matchPlayResult.isComplete else { continue }
            if let winnerId = match.winningTeamId {
                points += winnerId == teamId ? scoringRule.pointsPerWin : scoringRule.pointsPerLoss
            } else if match.isHalved {
                points += scoringRule.pointsPerHalve
            }
        }
        return points
    }

    /// Singles: points per hole won (only matches involving this team)
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

    /// Nines & Overall: points for front 9 win, back 9 win, and overall win (only matches involving this team)
    private func ninesAndOverallPoints(teamId: UUID) -> Double {
        var points = 0.0
        for match in ninesMatches {
            guard match.player1TeamId == teamId || match.player2TeamId == teamId else { continue }
            // Front 9
            if let winner = match.front9WinnerTeamId {
                points += winner == teamId ? scoringRule.nineWinPoints : 0
            } else if match.front9Halved {
                points += scoringRule.nineHalvePoints
            }

            // Back 9
            if let winner = match.back9WinnerTeamId {
                points += winner == teamId ? scoringRule.nineWinPoints : 0
            } else if match.back9Halved {
                points += scoringRule.nineHalvePoints
            }

            // Overall
            if let winner = match.overallWinnerTeamId {
                points += winner == teamId ? scoringRule.overallWinPoints : 0
            } else if match.overallHalved {
                points += scoringRule.overallHalvePoints
            }
        }
        return points
    }

    /// Stroke play / best ball: compare team totals against all other teams.
    /// For N teams: earns win/halve/loss points for each pairwise comparison.
    private func teamComparisonPoints(teamId: UUID) -> Double {
        guard teamScores.count >= 2 else { return 0 }
        guard let myScore = teamScores.first(where: { $0.teamId == teamId }) else { return 0 }

        var points = 0.0
        for otherScore in teamScores where otherScore.teamId != teamId {
            if myScore.totalNetScore < otherScore.totalNetScore {
                points += scoringRule.pointsPerWin
            } else if myScore.totalNetScore == otherScore.totalNetScore {
                points += scoringRule.pointsPerHalve
            } else {
                points += scoringRule.pointsPerLoss
            }
        }
        return points
    }

    /// Stroke play / best ball with F9/B9/OA: compare team segment scores pairwise.
    private func teamComparisonNinesPoints(teamId: UUID) -> Double {
        guard teamNinesScores.count >= 2 else { return 0 }
        guard let myScore = teamNinesScores.first(where: { $0.teamId == teamId }) else { return 0 }

        var points = 0.0
        for otherScore in teamNinesScores where otherScore.teamId != teamId {
            // Front 9
            if myScore.front9Net < otherScore.front9Net {
                points += scoringRule.nineWinPoints
            } else if myScore.front9Net == otherScore.front9Net {
                points += scoringRule.nineHalvePoints
            }
            // Back 9
            if myScore.back9Net < otherScore.back9Net {
                points += scoringRule.nineWinPoints
            } else if myScore.back9Net == otherScore.back9Net {
                points += scoringRule.nineHalvePoints
            }
            // Overall
            if myScore.overallNet < otherScore.overallNet {
                points += scoringRule.overallWinPoints
            } else if myScore.overallNet == otherScore.overallNet {
                points += scoringRule.overallHalvePoints
            }
        }
        return points
    }

    /// The winning team ID for team-comparison formats (stroke play / best ball), nil if tied or no scores.
    /// Returns the team with the lowest net score. nil if top two teams are tied.
    var winningTeamId: UUID? {
        guard teamScores.count >= 2 else { return nil }
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
        let base = scoringRule.format.shortName
        if scoringRule.effectiveUseNines && scoringRule.format != .ninesAndOverall {
            return "\(base) + F9/B9/OA"
        }
        return base
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

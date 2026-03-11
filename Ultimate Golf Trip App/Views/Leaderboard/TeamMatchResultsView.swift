import SwiftUI

// MARK: - Team Points Row

/// A row in the team standings section showing team name, points, and record
struct TeamPointsRowView: View {
    let standing: TeamPointsStanding
    let position: Int

    var body: some View {
        HStack(spacing: 10) {
            // Position
            Text("\(position)")
                .font(.title3)
                .fontWeight(.bold)
                .frame(width: 28)
                .foregroundStyle(position == 1 ? Theme.primary : Theme.textSecondary)

            // Team color dot
            Circle()
                .fill(standing.teamColor.color)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            // Team info
            VStack(alignment: .leading, spacing: 2) {
                Text(standing.teamName)
                    .font(.headline)
                Text(standing.recordDisplay)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            // Total points
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(standing.totalPoints, specifier: "%.1f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(position == 1 ? Theme.primary : Theme.textPrimary)
                Text("pts")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Position \(position), Team \(standing.teamName), \(standing.recordDisplay), \(standing.totalPoints, specifier: "%.1f") points")
    }
}

// MARK: - Individual Match Row

/// A row showing a single match result like "Alex def. Keith 3&2"
struct IndividualMatchRowView: View {
    let match: IndividualMatchResult
    let trip: Trip?
    let format: TeamScoringFormat

    init(match: IndividualMatchResult, trip: Trip?, format: TeamScoringFormat = .traditionalMatchPlay) {
        self.match = match
        self.trip = trip
        self.format = format
    }

    var body: some View {
        HStack(spacing: 8) {
            // Player 1 avatar
            playerAvatar(playerId: match.player1Id)

            // Match result text
            VStack(alignment: .leading, spacing: 2) {
                Text(format == .singlesMatchPlay ? match.singlesDisplayText : match.displayText)
                    .font(.subheadline)

                if let winningTeamId = match.winningTeamId,
                   let team = trip?.team(withId: winningTeamId) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(team.color.color)
                            .frame(width: 8, height: 8)
                        Text("\(team.name) wins")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                } else if match.isHalved {
                    Text("Halved")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else if match.isInProgress {
                    Text("In Progress")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            // Status icon
            if match.winningTeamId != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                    .font(.body)
            } else if match.isHalved {
                Image(systemName: "equal.circle.fill")
                    .foregroundStyle(Theme.warning)
                    .font(.body)
            } else if match.isInProgress {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)
                    .font(.body)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(format == .singlesMatchPlay ? match.singlesDisplayText : match.displayText)
    }

    private func playerAvatar(playerId: UUID) -> some View {
        let player = trip?.player(withId: playerId)
        let color = player?.avatarColor.color ?? .gray
        let initial = String(player?.initials.prefix(1) ?? "?")

        return Circle()
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay {
                Text(initial)
                    .font(.system(size: 10))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Nines Match Row

/// A row showing a nines & overall match result with front 9, back 9, and overall winners
struct NinesMatchRowView: View {
    let match: NinesMatchResult
    let trip: Trip?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Player pairing
            HStack(spacing: 8) {
                playerAvatar(playerId: match.player1Id)
                Text("\(match.player1Name) vs \(match.player2Name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if !match.isComplete {
                    Text("thru \(match.holesCompleted)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Segment results
            HStack(spacing: 16) {
                segmentResult(label: "F9", winnerId: match.front9WinnerTeamId, halved: match.front9Halved, available: match.front9Complete)
                segmentResult(label: "B9", winnerId: match.back9WinnerTeamId, halved: match.back9Halved, available: match.isComplete)
                segmentResult(label: "OA", winnerId: match.overallWinnerTeamId, halved: match.overallHalved, available: match.isComplete)
            }

            // Net score summary
            if match.front9Complete {
                HStack(spacing: 16) {
                    Text("\(match.player1Name): \(match.player1Front9Net)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if match.isComplete {
                        Text("+ \(match.player1Back9Net) = \(match.player1OverallNet)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 16) {
                    Text("\(match.player2Name): \(match.player2Front9Net)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if match.isComplete {
                        Text("+ \(match.player2Back9Net) = \(match.player2OverallNet)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(match.displayText)
    }

    @ViewBuilder
    private func segmentResult(label: String, winnerId: UUID?, halved: Bool, available: Bool) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            if !available {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else if let winnerId, let team = trip?.team(withId: winnerId) {
                Circle()
                    .fill(team.color.color)
                    .frame(width: 10, height: 10)
                Text(team.name)
                    .font(.caption)
                    .fontWeight(.semibold)
            } else if halved {
                Image(systemName: "equal.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
                Text("Halved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func playerAvatar(playerId: UUID) -> some View {
        let player = trip?.player(withId: playerId)
        let color = player?.avatarColor.color ?? .gray
        let initial = String(player?.initials.prefix(1) ?? "?")

        return Circle()
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay {
                Text(initial)
                    .font(.system(size: 10))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Team Score Row (for stroke play / best ball)

/// A row showing a team's score for a stroke play or best ball round
struct TeamScoreRowView: View {
    let teamScore: TeamRoundScore
    let isWinner: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(teamScore.teamColor.color)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            Text(teamScore.teamName)
                .font(.subheadline)
                .fontWeight(isWinner ? .bold : .regular)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("Net \(teamScore.totalNetScore)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                let toPar = teamScore.netScoreToPar
                Text(toPar == 0 ? "E" : (toPar > 0 ? "+\(toPar)" : "\(toPar)"))
                    .font(.caption)
                    .foregroundStyle(toPar < 0 ? .birdie : (toPar == 0 ? .par : .bogey))
            }

            if isWinner {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                    .font(.body)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(teamScore.teamName), net \(teamScore.totalNetScore)\(isWinner ? ", winner" : "")")
    }
}

// MARK: - Team Nines Score Row (for stroke play / best ball with F9/B9/OA)

/// A row showing a team's F9/B9/Overall net scores for a team-comparison nines round
struct TeamNinesScoreRowView: View {
    let score: TeamNinesScore
    let allScores: [TeamNinesScore]

    /// Whether this team has the lowest overall net among all teams
    private var isOverallBest: Bool {
        guard let best = allScores.min(by: { $0.overallNet < $1.overallNet }) else { return false }
        return score.teamId == best.teamId && score.overallNet < (allScores.filter { $0.teamId != score.teamId }.map(\.overallNet).min() ?? Int.max)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(score.teamColor.color)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)

            Text(score.teamName)
                .font(.subheadline)
                .fontWeight(isOverallBest ? .bold : .regular)

            Spacer()

            HStack(spacing: 12) {
                segmentLabel("F9", value: score.front9Net)
                segmentLabel("B9", value: score.back9Net)
                segmentLabel("OA", value: score.overallNet)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(score.teamName), Front 9: \(score.front9Net), Back 9: \(score.back9Net), Overall: \(score.overallNet)")
    }

    private func segmentLabel(_ label: String, value: Int) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(width: 32)
    }
}

// MARK: - Round Match Header

/// Header for each round's disclosure group showing round name, format, and per-team scores
struct RoundMatchHeaderView: View {
    let roundResult: RoundTeamMatchResult
    let trip: Trip?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(roundResult.roundLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(roundResult.formatLabel)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.primary.opacity(0.15))
                    .clipShape(Capsule())
            }

            if let trip = trip {
                HStack(spacing: 12) {
                    ForEach(trip.teams) { team in
                        let pts = roundResult.pointsForTeam(team.id)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(team.color.color)
                                .frame(width: 8, height: 8)
                            Text("\(team.name): \(pts, specifier: "%.1f")")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }

                    Spacer()

                    if !roundResult.ninesMatches.isEmpty {
                        Text("\(roundResult.ninesMatches.count) matches")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    } else if roundResult.scoringRule.format.isPerPlayerFormat {
                        Text("\(roundResult.individualMatches.count) matches")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(roundResult.roundLabel), \(roundResult.formatLabel)")
    }
}

// MARK: - Previews

#Preview("Team Points Row") {
    List {
        TeamPointsRowView(
            standing: TeamPointsStanding(
                teamId: UUID(),
                teamName: "Eagles",
                teamColor: .blue,
                totalPoints: 3.5,
                matchesWon: 3,
                matchesLost: 1,
                matchesHalved: 1,
                playerCount: 2,
                roundResults: []
            ),
            position: 1
        )
    }
}

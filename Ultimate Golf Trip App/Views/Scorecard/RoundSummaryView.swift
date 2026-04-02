import SwiftUI

/// One-stop review for a completed round: standings, match results, scorecard grid, and challenges.
struct RoundSummaryView: View {
    let round: Round
    let trip: Trip
    let course: Course

    private var players: [Player] {
        trip.players.filter { round.playerIds.contains($0.id) }
    }

    private var leaderboard: [LeaderboardEntry] {
        LeaderboardEngine.generateRoundLeaderboard(round: round, course: course, players: trip.players)
    }

    private var matchResult: RoundTeamMatchResult? {
        guard trip.teams.count >= 2 else { return nil }
        let rule = TeamMatchPlayEngine.resolveScoringRule(round: round, trip: trip)
        return TeamMatchPlayEngine.calculateRoundResults(
            round: round, course: course, players: trip.players, teams: trip.teams, scoringRule: rule
        )
    }

    private var roundChallenges: [SideBet] {
        trip.sideBets.filter { $0.round?.id == round.id }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                standingsSection

                if let result = matchResult, hasMatchContent(result) {
                    matchResultsSection(result)
                }

                scorecardGrid

                ForEach(players) { player in
                    if let card = round.scorecard(forPlayer: player.id) {
                        playerSummary(player: player, card: card)
                    }
                }

                if !roundChallenges.isEmpty {
                    challengesSection
                }
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Round Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(course.name)
                .font(.title2.bold())

            HStack(spacing: 16) {
                Label(round.formattedDate, systemImage: "calendar")
                Label(round.format.rawValue, systemImage: "flag.fill")
                Label("\(players.count) players", systemImage: "person.2")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !course.location.isEmpty {
                Text(course.location)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Standings

    private var standingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FINAL STANDINGS")
                .sectionHeader()

            ForEach(Array(leaderboard.enumerated()), id: \.element.playerId) { index, entry in
                HStack(spacing: 12) {
                    Text("\(entry.position)")
                        .font(.caption.bold())
                        .foregroundStyle(index == 0 ? Theme.primary : .secondary)
                        .frame(width: 24)

                    Circle()
                        .fill(trip.player(withId: entry.playerId)?.avatarColor.color ?? .blue)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Text(trip.player(withId: entry.playerId)?.initials ?? "?")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    Text(entry.playerName)
                        .font(.subheadline)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(entry.totalNet) net")
                            .font(.subheadline.bold())
                        let parText = entry.netScoreToPar == 0 ? "E" : (entry.netScoreToPar > 0 ? "+\(entry.netScoreToPar)" : "\(entry.netScoreToPar)")
                        Text(parText)
                            .font(.caption)
                            .foregroundStyle(entry.netScoreToPar <= 0 ? Theme.primary : .secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Match Results

    private func hasMatchContent(_ result: RoundTeamMatchResult) -> Bool {
        !result.individualMatches.isEmpty || !result.ninesMatches.isEmpty ||
        !result.bestBallMatches.isEmpty || !result.teamScores.isEmpty || !result.teamNinesScores.isEmpty
    }

    private func matchResultsSection(_ result: RoundTeamMatchResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("MATCH RESULTS")
                    .sectionHeader()
                Spacer()
                Text(result.formatLabel)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.primaryLight)
                    .clipShape(Capsule())
            }

            // Individual matches
            ForEach(result.individualMatches) { match in
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.displayText)
                        .font(.subheadline)
                    if match.isHalved {
                        Text("Halved")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Nines matches
            ForEach(result.ninesMatches) { match in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(match.player1Name) vs \(match.player2Name)")
                        .font(.subheadline.bold())
                    Text(match.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // Best ball matches
            ForEach(result.bestBallMatches) { match in
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.displayText)
                        .font(.subheadline)
                    HStack(spacing: 8) {
                        Circle().fill(match.team1Color.color).frame(width: 10, height: 10)
                        Text(match.team1Name).font(.caption)
                        Text("vs").font(.caption).foregroundStyle(.secondary)
                        Circle().fill(match.team2Color.color).frame(width: 10, height: 10)
                        Text(match.team2Name).font(.caption)
                    }
                }
                .padding(.vertical, 4)
            }

            // Team scores
            ForEach(result.teamScores) { score in
                HStack {
                    Circle().fill(score.teamColor.color).frame(width: 12, height: 12)
                    Text(score.teamName).font(.subheadline)
                    Spacer()
                    Text("\(score.totalNetScore) net").font(.subheadline.bold())
                }
            }

            // Team nines scores
            ForEach(result.teamNinesScores) { score in
                HStack {
                    Circle().fill(score.teamColor.color).frame(width: 12, height: 12)
                    Text(score.teamName).font(.subheadline)
                    Spacer()
                    Text("F9: \(score.front9Net)").font(.caption)
                    Text("B9: \(score.back9Net)").font(.caption)
                    Text("OA: \(score.overallNet)").font(.caption.bold())
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Scorecard Grid

    private var scorecardGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCORECARD")
                .sectionHeader()

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("Hole")
                            .font(.caption2.bold())
                            .frame(width: 60, alignment: .leading)
                        ForEach(course.holes, id: \.number) { hole in
                            Text("\(hole.number)")
                                .font(.caption2.bold())
                                .frame(width: 30)
                        }
                        Text("TOT")
                            .font(.caption2.bold())
                            .frame(width: 36)
                        Text("NET")
                            .font(.caption2.bold())
                            .frame(width: 36)
                    }
                    .padding(.vertical, 6)
                    .background(Theme.primaryLight)

                    // Par row
                    HStack(spacing: 0) {
                        Text("Par")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        ForEach(course.holes, id: \.number) { hole in
                            Text("\(hole.par)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 30)
                        }
                        Text("\(course.totalPar)")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                        Text("")
                            .frame(width: 36)
                    }
                    .padding(.vertical, 4)
                    .background(Theme.background)

                    Divider()

                    // Player rows
                    ForEach(players) { player in
                        if let card = round.scorecard(forPlayer: player.id) {
                            HStack(spacing: 0) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(player.avatarColor.color)
                                        .frame(width: 14, height: 14)
                                    Text(player.name.split(separator: " ").first.map(String.init) ?? player.name)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .frame(width: 60, alignment: .leading)

                                ForEach(card.holeScores) { score in
                                    Text(score.isCompleted ? "\(score.strokes)" : "-")
                                        .font(.caption2)
                                        .fontWeight(score.isCompleted ? .medium : .regular)
                                        .foregroundStyle(score.isCompleted ? score.scoreColor : .secondary)
                                        .frame(width: 30)
                                }

                                Text("\(card.totalGross)")
                                    .font(.caption2.bold())
                                    .frame(width: 36)

                                Text("\(card.totalNet)")
                                    .font(.caption2.bold())
                                    .frame(width: 36)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Player Summary

    private func playerSummary(player: Player, card: Scorecard) -> some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(player.avatarColor.color)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(player.initials)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }

                Text(player.name)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Gross: \(card.totalGross)")
                        .font(.subheadline)
                    Text("Net: \(card.totalNet)")
                        .font(.subheadline.bold())
                }
            }

            HStack(spacing: 16) {
                StatBox(label: "Front", value: "\(card.frontNineGross)")
                StatBox(label: "Back", value: "\(card.backNineGross)")
                StatBox(label: "Putts", value: "\(card.totalPutts)")
                StatBox(label: "HDCP", value: "\(card.courseHandicap)")
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
    }

    // MARK: - Challenge Results

    private var challengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHALLENGES")
                .sectionHeader()

            ForEach(roundChallenges) { bet in
                HStack {
                    Image(systemName: bet.betType.icon)
                        .foregroundStyle(Theme.primary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(bet.name)
                            .font(.subheadline.bold())
                        if bet.isCompleted, let winnerId = bet.winnerId,
                           let winner = trip.player(withId: winnerId) {
                            Text("\(winner.name) wins — \(bet.stake)")
                                .font(.caption)
                                .foregroundStyle(Theme.primary)
                        } else if bet.isActive {
                            Text("In Progress")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    if bet.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border, lineWidth: 1))
    }
}

struct StatBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
    }
}

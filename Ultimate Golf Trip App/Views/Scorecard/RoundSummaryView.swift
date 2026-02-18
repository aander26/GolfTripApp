import SwiftUI

struct RoundSummaryView: View {
    let round: Round
    let course: Course
    let players: [Player]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text(course.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(round.format.rawValue) - \(round.formattedDate)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()

                // Scorecard Grid
                scorecardGrid

                // Player Summaries
                ForEach(players) { player in
                    if let card = round.scorecard(forPlayer: player.id) {
                        playerSummary(player: player, card: card)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Round Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Scorecard Grid

    private var scorecardGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                // Header Row
                HStack(spacing: 0) {
                    Text("Hole")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .frame(width: 60, alignment: .leading)

                    ForEach(1...18, id: \.self) { hole in
                        Text("\(hole)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .frame(width: 30)
                    }

                    Text("TOT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .frame(width: 40)

                    Text("NET")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .frame(width: 40)
                }
                .padding(.vertical, 4)
                .background(Theme.primaryLight)

                // Par Row
                HStack(spacing: 0) {
                    Text("Par")
                        .font(.caption2)
                        .frame(width: 60, alignment: .leading)

                    ForEach(course.holes) { hole in
                        Text("\(hole.par)")
                            .font(.caption2)
                            .frame(width: 30)
                    }

                    Text("\(course.totalPar)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .frame(width: 40)

                    Text("")
                        .frame(width: 40)
                }
                .padding(.vertical, 4)
                .background(Theme.background)

                // Player Rows
                ForEach(players) { player in
                    if let card = round.scorecard(forPlayer: player.id) {
                        HStack(spacing: 0) {
                            Text(player.name.split(separator: " ").first.map(String.init) ?? player.name)
                                .font(.caption2)
                                .frame(width: 60, alignment: .leading)
                                .lineLimit(1)

                            ForEach(card.holeScores) { score in
                                Text(score.isCompleted ? "\(score.strokes)" : "-")
                                    .font(.caption2)
                                    .fontWeight(score.isCompleted ? .medium : .regular)
                                    .foregroundStyle(score.isCompleted ? score.scoreColor : .secondary)
                                    .frame(width: 30)
                            }

                            Text("\(card.totalGross)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .frame(width: 40)

                            Text("\(card.totalNet)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .frame(width: 40)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
                            .font(.system(size: 10))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }

                Text(player.name)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing) {
                    Text("Gross: \(card.totalGross)")
                        .font(.subheadline)
                    Text("Net: \(card.totalNet)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RoundSummaryView(
        round: SampleData.round,
        course: SampleData.course,
        players: SampleData.playersWithTeams
    )
}

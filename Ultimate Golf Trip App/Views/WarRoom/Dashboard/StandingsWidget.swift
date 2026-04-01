import SwiftUI

struct StandingsWidget: View {
    let entries: [LeaderboardEntry]
    var onSeeAll: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Standings")
                    .sectionHeader()
                Spacer()
                if !entries.isEmpty, let onSeeAll {
                    Button(action: onSeeAll) {
                        Text("See All")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.primary)
                    }
                }
            }

            if entries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "trophy")
                            .font(.title2)
                            .foregroundStyle(Theme.textSecondary)
                        Text("No rounds played yet")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 16)
                    Spacer()
                }
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(3).enumerated()), id: \.element.id) { index, entry in
                        HStack(spacing: 12) {
                            positionBadge(index + 1)

                            Text(entry.playerName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(formattedScore(entry.netScoreToPar))
                                .font(.subheadline.bold())
                                .foregroundStyle(
                                    entry.netScoreToPar < 0 ? Theme.primary :
                                    entry.netScoreToPar == 0 ? Theme.textPrimary :
                                    Theme.error
                                )

                            Text("\(entry.roundsCompleted)R")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if index < min(entries.count, 3) - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .cardStyle(padded: false)
            }
        }
    }

    @ViewBuilder
    private func positionBadge(_ position: Int) -> some View {
        let icon: String = switch position {
        case 1: "trophy.fill"
        case 2: "medal.fill"
        case 3: "3.circle.fill"
        default: "\(position).circle"
        }

        let color: Color = switch position {
        case 1: Color(red: 1.0, green: 0.84, blue: 0.0) // gold
        case 2: Color(red: 0.75, green: 0.75, blue: 0.75) // silver
        case 3: Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
        default: Theme.textSecondary
        }

        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(color)
            .frame(width: 24)
    }

    private func formattedScore(_ scoreToPar: Int) -> String {
        if scoreToPar == 0 { return "E" }
        return scoreToPar > 0 ? "+\(scoreToPar)" : "\(scoreToPar)"
    }
}

import SwiftUI

struct ActiveChallengesWidget: View {
    let challenges: [SideBet]
    let standingsResolver: (SideBet) -> [ChallengesViewModel.PlayerStanding]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Challenges")
                    .sectionHeader()
                Spacer()
                Text("\(challenges.count)")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Theme.primaryMuted)
                    .clipShape(Capsule())
            }

            if challenges.isEmpty {
                Text("No active challenges yet")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(challenges) { challenge in
                            challengeCard(challenge)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func challengeCard(_ challenge: SideBet) -> some View {
        let standings = standingsResolver(challenge)
        let leader = standings.first(where: { $0.isLeader })

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: challenge.challengeType.icon)
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
                Text(challenge.challengeType.shortLabel)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            Text(challenge.name)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let leader {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text(leader.playerName)
                        .font(.caption.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                Text(leader.label)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                Text("No scores yet")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            HStack(spacing: 4) {
                Image(systemName: "dollarsign.circle")
                    .font(.caption2)
                Text(challenge.stake)
                    .font(.caption2)
            }
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(12)
        .frame(width: 160, height: 160)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
    }
}

// MARK: - ChallengeType helpers

extension ChallengeType {
    var shortLabel: String {
        switch self {
        case .mostBirdies: return "Birdies"
        case .fewestPutts: return "Putts"
        case .fewest3Putts: return "3-Putts"
        case .most3Putts: return "3-Putts"
        case .lowRound: return "Low Round"
        case .headToHeadRound: return "H2H"
        case .highestTotal: return "High Total"
        case .lowestTotal: return "Low Total"
        case .closestToTarget: return "Target"
        case .overUnder: return "Over/Under"
        case .headToHead: return "Head to Head"
        case .custom: return "Custom"
        }
    }
}

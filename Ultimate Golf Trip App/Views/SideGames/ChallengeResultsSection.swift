import SwiftUI

/// Inline results dashboard showing real-time standings for all active challenges.
struct ChallengeResultsSection: View {
    @Bindable var viewModel: ChallengesViewModel

    var body: some View {
        let activeBets = viewModel.activeBets
        let betsAndStandings: [(SideBet, [ChallengesViewModel.PlayerStanding])] = activeBets.compactMap { bet in
            let standings = viewModel.liveStandings(for: bet)
            return standings.isEmpty ? nil : (bet, standings)
        }

        if !betsAndStandings.isEmpty {
            Section {
                ForEach(betsAndStandings, id: \.0.id) { bet, standings in
                    challengeResultCard(bet, standings: standings)
                }
            } header: {
                HStack {
                    Text("Live Results")
                    Spacer()
                    HStack(spacing: 3) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                        Text("\(betsAndStandings.count) active")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func challengeResultCard(_ bet: SideBet, standings: [ChallengesViewModel.PlayerStanding]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: bet.betType.icon)
                    .font(.caption)
                    .foregroundStyle(Theme.primary)
                Text(bet.name)
                    .font(.subheadline.bold())

                Spacer()

                Text(bet.betType.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.primaryLight)
                    .foregroundStyle(Theme.primary)
                    .clipShape(Capsule())
            }

            // Round info
            if let roundName = bet.roundDisplayName {
                Text(roundName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Mini leaderboard
            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption2.bold())
                        .foregroundStyle(index == 0 ? Theme.primary : .secondary)
                        .frame(width: 14, alignment: .trailing)

                    Text(standing.playerName.split(separator: " ").first.map(String.init) ?? standing.playerName)
                        .font(.caption)
                        .fontWeight(standing.isLeader ? .semibold : .regular)

                    Spacer()

                    Text(standing.label)
                        .font(.caption.bold())
                        .foregroundStyle(standing.isLeader ? Theme.primary : .primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

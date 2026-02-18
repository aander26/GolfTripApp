import SwiftUI

struct PollCardView: View {
    let poll: Poll
    let players: [Player]
    let currentPlayerId: UUID?
    let onVote: (UUID, UUID) -> Void
    let onClose: () -> Void

    private var hasVoted: Bool {
        guard let playerId = currentPlayerId else { return false }
        return poll.hasVoted(playerId: playerId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Theme.primary)
                Text(poll.question)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if poll.isActive {
                    Menu {
                        Button(role: .destructive, action: onClose) {
                            Label("Close Poll", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel("Poll options")
                }
            }

            // Options
            ForEach(poll.options) { option in
                PollOptionRow(
                    option: option,
                    totalVotes: poll.totalVotes,
                    isSelected: currentPlayerId.map { option.voterIds.contains($0) } ?? false,
                    showResults: hasVoted || !poll.isActive,
                    players: players,
                    onTap: {
                        if poll.isActive, let playerId = currentPlayerId {
                            onVote(option.id, playerId)
                        }
                    }
                )
            }

            // Footer
            HStack {
                Text("\(poll.totalVotes) vote\(poll.totalVotes == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !poll.isActive {
                    Text("Closed")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.error)
                }
            }
        }
        .padding()
        .cardStyle(padded: false)
    }
}

struct PollOptionRow: View {
    let option: PollOption
    let totalVotes: Int
    let isSelected: Bool
    let showResults: Bool
    let players: [Player]
    let onTap: () -> Void

    private var percentage: Double {
        guard totalVotes > 0 else { return 0 }
        return Double(option.voteCount) / Double(totalVotes)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.primary)
                            .font(.caption)
                    }
                    Text(option.text)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if showResults {
                        Text("\(option.voteCount)")
                            .font(.subheadline.bold())
                            .foregroundStyle(Theme.textPrimary)
                    }
                }

                if showResults {
                    // Bold Links: emerald at 20% opacity for bar background
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.primaryMuted)
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(isSelected ? Theme.primary : Theme.primary.opacity(0.5))
                                .frame(width: geometry.size.width * percentage, height: 6)
                        }
                    }
                    .frame(height: 6)

                    // Voter avatars with Bold Links ring style
                    if !option.voterIds.isEmpty {
                        HStack(spacing: -4) {
                            let voters = option.voterIds.compactMap { id in
                                players.first { $0.id == id }
                            }
                            ForEach(Array(voters.prefix(5))) { voter in
                                Text(voter.initials)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(voter.avatarColor.color)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                            }
                            Spacer()
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Theme.primaryMuted : Theme.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Theme.primary.opacity(0.3) : .clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.text)\(isSelected ? ", your vote" : "")\(showResults ? ", \(option.voteCount) votes, \(Int(percentage * 100))%" : "")")
        .accessibilityHint(isSelected ? "Tap to remove your vote" : "Tap to vote")
    }
}

#Preview {
    let players = SampleData.playersWithTeams
    let poll = Poll(
        question: "Which course should we play Saturday?",
        options: [
            PollOption(text: "TPC Scottsdale", voterIds: [players[0].id, players[1].id]),
            PollOption(text: "Troon North", voterIds: [players[2].id]),
            PollOption(text: "We-Ko-Pa", voterIds: [])
        ]
    )
    PollCardView(
        poll: poll,
        players: players,
        currentPlayerId: players[0].id,
        onVote: { _, _ in },
        onClose: {}
    )
    .padding()
    .background(Theme.background)
}

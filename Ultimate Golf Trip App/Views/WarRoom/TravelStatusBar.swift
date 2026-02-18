import SwiftUI

struct TravelStatusBar: View {
    @Bindable var viewModel: WarRoomViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Squad Status")
                    .sectionHeader()
                Spacer()
                Button {
                    viewModel.showingStatusPicker = true
                } label: {
                    Text("Update")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.playerStatuses, id: \.0.id) { player, status in
                        PlayerStatusBubble(
                            player: player,
                            status: status
                        )
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .padding()
        .cardStyle(padded: false)
    }
}

struct PlayerStatusBubble: View {
    let player: Player
    let status: TravelStatus?

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Text(player.initials)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(player.avatarColor.color)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Theme.cardBackground, lineWidth: 2)
                            .padding(-2)
                    )

                // Status emoji badge
                Text(statusEmoji)
                    .font(.system(size: 14))
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(Theme.cardBackground)
                            .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    )
                    .offset(x: 4, y: 4)
            }

            Text(player.name.split(separator: " ").first.map(String.init) ?? player.name)
                .font(.caption2)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Text(statusText)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 64)
    }

    private var statusEmoji: String {
        status?.status.emoji ?? TravelStatusType.notDeparted.emoji
    }

    private var statusText: String {
        if let status {
            return status.timeSinceUpdate
        }
        return "No update"
    }
}

#Preview {
    TravelStatusBar(viewModel: SampleData.makeWarRoomViewModel())
        .padding()
        .background(Theme.background)
        .environment(SampleData.makeAppState())
}

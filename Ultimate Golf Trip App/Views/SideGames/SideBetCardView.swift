import SwiftUI

struct SideBetCardView: View {
    let bet: SideBet
    @Bindable var viewModel: MetricsViewModel
    @State private var showingWinnerPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: bet.betType.icon)
                    .foregroundStyle(Theme.primary)
                Text(bet.name)
                    .font(.headline)

                if bet.isPotBet {
                    Text("POT")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Spacer()

                if bet.isPotBet && bet.potAmount > 0 {
                    Text("$\(String(format: "%.0f", bet.totalPot))")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryLight)
                        .clipShape(Capsule())
                } else {
                    Text(bet.stake)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryLight)
                        .clipShape(Capsule())
                }
            }

            // Metric info
            HStack(spacing: 4) {
                if let metric = bet.metric {
                    Text(metric.icon)
                    Text(metric.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("·")
                    .foregroundStyle(.secondary)
                Text(bet.betType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let target = bet.formattedTarget {
                    Text("· Target: \(target)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if bet.isPotBet && bet.potAmount > 0 {
                    Text("· $\(String(format: "%.0f", bet.potAmount))/player")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Participant standings
            let standings = participantStandings
            if !standings.isEmpty {
                VStack(spacing: 4) {
                    ForEach(standings, id: \.playerId) { standing in
                        HStack(spacing: 8) {
                            Text(standing.playerName.split(separator: " ").first.map(String.init) ?? standing.playerName)
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geometry in
                                let maxVal = standings.map(\.value).max() ?? 1
                                let width = maxVal > 0 ? (standing.value / maxVal) * geometry.size.width : 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(standing.isWinner ? Theme.primary : Theme.primary.opacity(0.3))
                                    .frame(width: max(width, 2), height: 14)
                            }
                            .frame(height: 14)

                            Text("\(standing.value, specifier: standing.value == standing.value.rounded() ? "%.0f" : "%.1f")")
                                .font(.caption.bold())
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
            }

            // Status / Actions
            HStack {
                if bet.isCompleted {
                    if let winnerId = bet.winnerId,
                       let winner = viewModel.currentTrip?.player(withId: winnerId) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text("\(winner.name) wins!")
                                .font(.caption.bold())
                                .foregroundStyle(Theme.primary)
                        }
                    } else {
                        Text("Completed")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Active")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primary)
                }

                Spacer()

                if bet.isActive {
                    Menu {
                        Button {
                            showingWinnerPicker = true
                        } label: {
                            Label("Declare Winner", systemImage: "trophy")
                        }
                        Button {
                            viewModel.completeBet(bet.id)
                        } label: {
                            Label("Auto-Settle from Stats", systemImage: "chart.bar")
                        }
                        Divider()
                        Button(role: .destructive) {
                            viewModel.deleteBet(bet.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingWinnerPicker) {
            BetWinnerPickerSheet(bet: bet, viewModel: viewModel)
        }
    }

    private struct ParticipantStanding {
        let playerId: UUID
        let playerName: String
        let value: Double
        let isWinner: Bool
    }

    private var participantStandings: [ParticipantStanding] {
        guard let trip = viewModel.currentTrip,
              let metric = bet.metric else { return [] }

        return bet.participants.compactMap { playerId -> ParticipantStanding? in
            guard let player = trip.player(withId: playerId) else { return nil }
            let total = trip.totalValue(forMetric: metric.id, member: playerId)
            return ParticipantStanding(
                playerId: playerId,
                playerName: player.name,
                value: total,
                isWinner: bet.winnerId == playerId
            )
        }
        .sorted { a, b in
            metric.higherIsBetter ? a.value > b.value : a.value < b.value
        }
    }
}

// MARK: - Winner Picker Sheet

struct BetWinnerPickerSheet: View {
    let bet: SideBet
    @Bindable var viewModel: MetricsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWinnerId: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Bet info header
                VStack(spacing: 6) {
                    Text(bet.name)
                        .font(.title3.bold())

                    if bet.isPotBet && bet.potAmount > 0 {
                        Text(bet.potDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Stakes: \(bet.stake)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                Divider()

                // Player list
                List {
                    Section("Select the Winner") {
                        ForEach(viewModel.betParticipants(for: bet)) { player in
                            Button {
                                selectedWinnerId = player.id
                            } label: {
                                HStack {
                                    Text(player.initials)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(player.avatarColor.color)
                                        .clipShape(Circle())

                                    Text(player.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedWinnerId == player.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.primary)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                            .font(.title3)
                                    }
                                }
                            }
                        }
                    }

                    // Show what winning means for pot bets
                    if bet.isPotBet && bet.potAmount > 0 {
                        Section {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                                Text("Winner takes the $\(String(format: "%.0f", bet.totalPot)) pot. This will appear in Settle Up.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Declare Winner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if let winnerId = selectedWinnerId {
                            viewModel.completeBetWithWinner(betId: bet.id, winnerId: winnerId)
                        }
                        dismiss()
                    }
                    .disabled(selectedWinnerId == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let appState = SampleData.makeAppState()
    let vm = MetricsViewModel(appState: appState)
    let players = SampleData.playersWithTeams
    let bet = SideBet(
        name: "Most Birdies",
        metric: nil,
        betType: .highestTotal,
        participants: players.map(\.id),
        stake: "$20"
    )
    List {
        SideBetCardView(bet: bet, viewModel: vm)
    }
}

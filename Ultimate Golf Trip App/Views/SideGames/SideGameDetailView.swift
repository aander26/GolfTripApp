import SwiftUI

struct SideGameDetailView: View {
    @Bindable var viewModel: SideGameViewModel
    let game: SideGame
    @State private var showingAddResult = false

    var body: some View {
        List {
            // Game Info
            Section {
                LabeledContent("Type", value: game.type.rawValue)
                LabeledContent("Stakes", value: game.stakesLabel)
                LabeledContent("Players", value: "\(game.participantIds.count)")
                LabeledContent("Status", value: game.isActive ? "Active" : "Completed")
            }

            // Standings
            Section("Standings") {
                let standings = viewModel.standings(for: game.id)
                if standings.isEmpty {
                    Text("No results yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(standings, id: \.playerId) { standing in
                        HStack {
                            if let player = viewModel.currentTrip?.player(withId: standing.playerId) {
                                Circle()
                                    .fill(player.avatarColor.color)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Text(player.initials)
                                            .font(.system(size: 9))
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }
                            }

                            Text(standing.playerName)
                                .font(.body)

                            Spacer()

                            Text(standing.amount >= 0 ? "+$\(String(format: "%.0f", standing.amount))" : "-$\(String(format: "%.0f", abs(standing.amount)))")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(standing.amount >= 0 ? .green : .red)
                        }
                    }
                }
            }

            // Results History
            Section("Results") {
                if game.results.isEmpty {
                    Text("No results recorded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(game.results) { result in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                if result.holeNumber > 0 {
                                    Text("Hole \(result.holeNumber)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Theme.primaryLight)
                                        .clipShape(Capsule())
                                }

                                Text(result.description)
                                    .font(.subheadline)

                                Spacer()

                                if result.amount != 0 {
                                    Text("$\(String(format: "%.0f", abs(result.amount)))")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                            }

                            if let winnerId = result.winnerId,
                               let player = viewModel.currentTrip?.player(withId: winnerId) {
                                Text(player.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if result.isCarryOver {
                                Text("Carries over")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Actions
            Section {
                if game.isActive {
                    Button("Calculate Results") {
                        viewModel.calculateResults(for: game.id)
                    }

                    Button {
                        showingAddResult = true
                    } label: {
                        Label("Add Manual Result", systemImage: "plus")
                    }

                    Button("End Game") {
                        viewModel.endSideGame(game.id)
                    }
                    .foregroundStyle(.orange)
                }

                Button("Delete Game", role: .destructive) {
                    viewModel.deleteSideGame(game.id)
                }
            }
        }
        .navigationTitle(game.type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddResult) {
            AddResultSheet(viewModel: viewModel, gameId: game.id)
        }
    }
}

struct AddResultSheet: View {
    @Bindable var viewModel: SideGameViewModel
    let gameId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var selectedHole = 1
    @State private var selectedWinner: UUID?
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Hole") {
                    Picker("Hole", selection: $selectedHole) {
                        ForEach(1...18, id: \.self) { hole in
                            Text("Hole \(hole)").tag(hole)
                        }
                    }
                }

                Section("Winner") {
                    if let trip = viewModel.currentTrip,
                       let game = trip.sideGames.first(where: { $0.id == gameId }) {
                        ForEach(trip.players.filter({ game.participantIds.contains($0.id) })) { player in
                            HStack {
                                Text(player.name)
                                Spacer()
                                if selectedWinner == player.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedWinner = player.id
                            }
                        }
                    }
                }

                Section("Description") {
                    TextField("e.g., Closest to pin - 4 feet", text: $description)
                }
            }
            .navigationTitle("Add Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let winner = selectedWinner {
                            viewModel.addManualResult(
                                gameId: gameId,
                                holeNumber: selectedHole,
                                winnerId: winner,
                                description: description
                            )
                        }
                        dismiss()
                    }
                    .disabled(selectedWinner == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SideGameDetailView(
            viewModel: SampleData.makeSideGameViewModel(),
            game: SampleData.sideGame
        )
    }
}

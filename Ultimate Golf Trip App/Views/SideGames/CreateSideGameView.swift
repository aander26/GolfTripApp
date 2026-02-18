import SwiftUI

struct CreateSideGameView: View {
    @Bindable var viewModel: SideGameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Game Type
                Section("Game Type") {
                    Picker("Type", selection: $viewModel.selectedGameType) {
                        ForEach(SideGameType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Text(viewModel.selectedGameType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Round Selection
                if let trip = viewModel.currentTrip, !trip.rounds.isEmpty {
                    Section("Round") {
                        Picker("Round", selection: $viewModel.selectedRoundId) {
                            Text("All Rounds").tag(UUID?.none)
                            ForEach(Array(trip.rounds.enumerated()), id: \.element.id) { index, round in
                                let courseName = round.course?.name ?? "Round"
                                Text("R\(index + 1): \(courseName)").tag(Optional(round.id))
                            }
                        }
                    }
                }

                // Stakes
                Section("Stakes") {
                    Toggle("Pot Mode", isOn: $viewModel.isPotGame)

                    HStack {
                        Text("$")
                        TextField(
                            viewModel.isPotGame ? "Buy-in per player" : "Amount per unit",
                            text: $viewModel.stakesAmount
                        )
                        .keyboardType(.decimalPad)
                    }

                    if viewModel.isPotGame {
                        let stakes = Double(viewModel.stakesAmount) ?? 0
                        let playerCount = viewModel.selectedParticipantIds.count
                        if stakes > 0 && playerCount > 0 {
                            let total = stakes * Double(playerCount)
                            HStack {
                                Image(systemName: "banknote")
                                    .foregroundStyle(Theme.primary)
                                Text("\(playerCount) players x $\(String(format: "%.0f", stakes)) = **$\(String(format: "%.0f", total)) pot**")
                                    .font(.subheadline)
                            }
                            .listRowBackground(Theme.primaryLight.opacity(0.3))
                        } else {
                            Text("Select players and enter a buy-in to see the pot total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Players
                if let trip = viewModel.currentTrip {
                    Section("Players") {
                        ForEach(trip.players) { player in
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

                                Spacer()

                                Image(systemName: viewModel.selectedParticipantIds.contains(player.id)
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(viewModel.selectedParticipantIds.contains(player.id) ? Theme.primary : Theme.textSecondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if viewModel.selectedParticipantIds.contains(player.id) {
                                    viewModel.selectedParticipantIds.remove(player.id)
                                } else {
                                    viewModel.selectedParticipantIds.insert(player.id)
                                }
                            }
                        }

                        Button("Select All") {
                            viewModel.selectedParticipantIds = Set(trip.players.map(\.id))
                        }
                        .font(.subheadline)
                    }
                }

                // Designated Holes (for CTP and Long Drive)
                if viewModel.selectedGameType == .closestToPin || viewModel.selectedGameType == .longDrive {
                    Section("Designated Holes") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                            ForEach(1...18, id: \.self) { hole in
                                Button {
                                    if viewModel.designatedHoles.contains(hole) {
                                        viewModel.designatedHoles.remove(hole)
                                    } else {
                                        viewModel.designatedHoles.insert(hole)
                                    }
                                } label: {
                                    Text("\(hole)")
                                        .font(.caption)
                                        .frame(width: 36, height: 36)
                                        .background(
                                            viewModel.designatedHoles.contains(hole)
                                                ? Theme.primary
                                                : Theme.background
                                        )
                                        .foregroundStyle(viewModel.designatedHoles.contains(hole) ? .white : .primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("New Side Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createSideGame()
                        dismiss()
                    }
                    .disabled(viewModel.selectedParticipantIds.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    CreateSideGameView(viewModel: SampleData.makeSideGameViewModel())
}

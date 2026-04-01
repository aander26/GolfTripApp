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
                Section("Points") {
                    Toggle("Pool Mode", isOn: $viewModel.isPotGame)

                    TextField(
                        viewModel.isPotGame ? "Entry per player" : "Points per unit",
                        text: $viewModel.stakesAmount
                    )
                    .keyboardType(.decimalPad)

                    if viewModel.isPotGame {
                        let stakes = Double(viewModel.stakesAmount) ?? 0
                        let playerCount = viewModel.selectedParticipantIds.count
                        if stakes > 0 && playerCount > 0 {
                            let total = stakes * Double(playerCount)
                            HStack {
                                Image(systemName: "person.3.fill")
                                    .foregroundStyle(Theme.primary)
                                Text("\(playerCount) players \u{00D7} \(String(format: "%.0f", stakes)) pts = **\(String(format: "%.0f", total)) pt pool**")
                                    .font(.subheadline)
                            }
                            .listRowBackground(Theme.primaryLight.opacity(0.3))
                        } else {
                            Text("Select players and enter points to see the pool total")
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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 6) {
                            let holeCount = viewModel.currentTrip?.rounds.first(where: { $0.id == viewModel.selectedRoundId })?.course?.holes.count
                                ?? viewModel.currentTrip?.courses.first?.holes.count ?? 18
                            ForEach(1...holeCount, id: \.self) { hole in
                                Button {
                                    if viewModel.designatedHoles.contains(hole) {
                                        viewModel.designatedHoles.remove(hole)
                                    } else {
                                        viewModel.designatedHoles.insert(hole)
                                    }
                                } label: {
                                    Text("\(hole)")
                                        .font(.subheadline)
                                        .frame(minWidth: 44, minHeight: 44)
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
                    .disabled(viewModel.selectedParticipantIds.count < 2 || (Double(viewModel.stakesAmount) ?? 0) <= 0)
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
}

#Preview {
    CreateSideGameView(viewModel: SampleData.makeSideGameViewModel())
}

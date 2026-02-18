import SwiftUI

struct CreateSideBetView: View {
    @Bindable var viewModel: MetricsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Bet Name") {
                    TextField("e.g. Most Birdies", text: $viewModel.newBetName)
                }

                Section("Metric") {
                    if viewModel.allMetrics.isEmpty {
                        Text("Add some tracked stats first!")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Based on", selection: $viewModel.newBetMetricId) {
                            Text("Select a stat").tag(UUID?.none)
                            ForEach(viewModel.allMetrics) { metric in
                                HStack {
                                    Text(metric.icon)
                                    Text(metric.name)
                                }
                                .tag(UUID?.some(metric.id))
                            }
                        }
                    }
                }

                Section("Bet Type") {
                    Picker("Type", selection: $viewModel.newBetType) {
                        ForEach(BetType.allCases) { type in
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }

                    Text(viewModel.newBetType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if viewModel.newBetType == .closestToTarget || viewModel.newBetType == .overUnder {
                        TextField("Target Value", text: $viewModel.newBetTargetValue)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Participants") {
                    if let trip = viewModel.currentTrip {
                        ForEach(trip.players) { player in
                            Button {
                                if viewModel.newBetParticipants.contains(player.id) {
                                    viewModel.newBetParticipants.remove(player.id)
                                } else {
                                    viewModel.newBetParticipants.insert(player.id)
                                }
                            } label: {
                                HStack {
                                    Text(player.initials)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(player.avatarColor.color)
                                        .clipShape(Circle())
                                    Text(player.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.newBetParticipants.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.primary)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Button("Select All") {
                            viewModel.newBetParticipants = Set(trip.players.map(\.id))
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.primary)
                    }
                }

                Section("Stakes") {
                    Toggle("Pot Mode", isOn: $viewModel.newBetIsPot)

                    if viewModel.newBetIsPot {
                        HStack {
                            Text("Buy-in per player")
                            Spacer()
                            HStack(spacing: 2) {
                                Text("$")
                                    .foregroundStyle(.secondary)
                                TextField("10", text: $viewModel.newBetPotAmount)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                            }
                        }

                        if let potValue = Double(viewModel.newBetPotAmount),
                           potValue > 0,
                           viewModel.newBetParticipants.count >= 2 {
                            let total = potValue * Double(viewModel.newBetParticipants.count)
                            HStack {
                                Image(systemName: "dollarsign.circle.fill")
                                    .foregroundStyle(Theme.primary)
                                Text("\(viewModel.newBetParticipants.count) players × $\(String(format: "%.0f", potValue)) = **$\(String(format: "%.0f", total)) pot**")
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        TextField("e.g. $20 or buys dinner", text: $viewModel.newBetStake)
                    }
                }
            }
            .navigationTitle("Create Side Bet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetBetForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createBet()
                        dismiss()
                    }
                    .disabled(!canCreate)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var canCreate: Bool {
        !viewModel.newBetName.isEmpty &&
        viewModel.newBetMetricId != nil &&
        viewModel.newBetParticipants.count >= 2
    }
}

#Preview {
    CreateSideBetView(viewModel: SampleData.makeMetricsViewModel())
}

import SwiftUI

struct LogEntrySheet: View {
    @Bindable var viewModel: MetricsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let metric = viewModel.selectedMetric {
                    Section {
                        HStack {
                            Text(metric.icon)
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(metric.name)
                                    .font(.headline)
                                Text(metric.trackingType.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Value") {
                        HStack {
                            TextField("0", text: $viewModel.entryValue)
                                .keyboardType(.decimalPad)
                                .font(.title2.bold())
                            if !metric.unit.isEmpty {
                                Text(metric.unit)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Player") {
                        if let trip = viewModel.currentTrip {
                            ForEach(trip.players) { player in
                                Button {
                                    viewModel.entryPlayerId = player.id
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
                                        if viewModel.entryPlayerId == player.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Theme.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if metric.category == .onCourse {
                        Section("Round (Optional)") {
                            if let trip = viewModel.currentTrip, !trip.rounds.isEmpty {
                                Picker("Round", selection: $viewModel.entryRoundId) {
                                    Text("None").tag(UUID?.none)
                                    ForEach(trip.rounds) { round in
                                        Text(round.course?.name ?? "Round")
                                            .tag(UUID?.some(round.id))
                                    }
                                }
                            } else {
                                Text("No rounds available")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Notes (Optional)") {
                        TextField("Add context...", text: $viewModel.entryNotes, axis: .vertical)
                            .lineLimit(2...4)
                    }
                }
            }
            .navigationTitle("Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetEntryForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        viewModel.logEntry()
                        dismiss()
                    }
                    .disabled(viewModel.entryValue.isEmpty || viewModel.entryPlayerId == nil)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    let vm = SampleData.makeMetricsViewModel()
    vm.selectedMetric = Metric.presetOnCourse[0]
    return LogEntrySheet(viewModel: vm)
}

import SwiftUI

struct AddMetricSheet: View {
    @Bindable var viewModel: MetricsViewModel
    @Environment(\.dismiss) private var dismiss

    private let emojiOptions = ["📊", "🐦", "🏌️", "🎯", "🟢", "🏖️", "😬", "🚫", "💧", "🔍",
                                 "🍺", "😴", "👟", "💤", "💸", "⏰", "😤", "🤣", "🏆", "⭐",
                                 "🔥", "💪", "🎉", "🍕", "☕", "🥃", "🎶", "📸"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Stat Name", text: $viewModel.newMetricName)
                    TextField("Unit (e.g. putts, beers)", text: $viewModel.newMetricUnit)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(emojiOptions, id: \.self) { emoji in
                                Button {
                                    viewModel.newMetricIcon = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.title2)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            viewModel.newMetricIcon == emoji
                                                ? Theme.primaryMuted
                                                : Theme.background
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(viewModel.newMetricIcon == emoji ? Theme.primary : .clear, lineWidth: 2)
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Tracking") {
                    Picker("How is it tracked?", selection: $viewModel.newMetricTrackingType) {
                        ForEach(TrackingType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Picker("Category", selection: $viewModel.newMetricCategory) {
                        ForEach(MetricCategory.allCases) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                }

                Section("Scoring") {
                    Toggle("Higher is Better", isOn: $viewModel.newMetricHigherIsBetter)
                    Text(viewModel.newMetricHigherIsBetter
                         ? "The player with the highest total wins"
                         : "The player with the lowest total wins")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Stat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetMetricForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addMetric()
                        dismiss()
                    }
                    .disabled(viewModel.newMetricName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    AddMetricSheet(viewModel: SampleData.makeMetricsViewModel())
}

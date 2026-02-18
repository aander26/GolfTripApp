import SwiftUI

struct MetricListView: View {
    @Bindable var viewModel: MetricsViewModel
    let category: MetricCategory

    private var metrics: [Metric] {
        category == .onCourse ? viewModel.onCourseMetrics : viewModel.offCourseMetrics
    }

    var body: some View {
        if metrics.isEmpty {
            emptyState
        } else {
            List {
                ForEach(metrics) { metric in
                    NavigationLink {
                        MetricDetailView(viewModel: viewModel, metric: metric)
                    } label: {
                        MetricRowView(
                            metric: metric,
                            standings: viewModel.standings(for: metric.id)
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            viewModel.deleteMetric(metric.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: category.icon)
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("No \(category.displayName) Stats")
                .font(.title2)
                .fontWeight(.bold)

            Text(category == .onCourse
                 ? "Track birdies, putts, fairways hit, and more."
                 : "Track beers consumed, hours slept, steps walked, and more.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack(spacing: 12) {
                Button {
                    viewModel.selectedCategory = category
                    viewModel.showingPresetPicker = true
                } label: {
                    Label("Add from Presets", systemImage: "list.bullet")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
            }

            Spacer()
        }
    }
}

struct MetricRowView: View {
    let metric: Metric
    let standings: [MetricsViewModel.MetricStanding]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(metric.icon)
                    .font(.title2)
                Text(metric.name)
                    .font(.headline)
                Spacer()
                Text(metric.trackingType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.background)
                    .clipShape(Capsule())
            }

            if let leader = standings.first, leader.total > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(leader.player.name.split(separator: " ").first.map(String.init) ?? leader.player.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text("\(leader.total, specifier: leader.total == leader.total.rounded() ? "%.0f" : "%.1f")\(metric.formattedUnit)")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.primary)
                }
            } else {
                Text("No entries yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Image(systemName: metric.higherIsBetter ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(metric.higherIsBetter ? .green : .blue)
                Text(metric.higherIsBetter ? "Higher is better" : "Lower is better")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    @Bindable var viewModel: MetricsViewModel
    @Environment(\.dismiss) private var dismiss

    private var presets: [Metric] {
        viewModel.selectedCategory == .onCourse
            ? Metric.presetOnCourse
            : Metric.presetOffCourse
    }

    private var existingNames: Set<String> {
        Set(viewModel.allMetrics.map(\.name))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(presets) { preset in
                        let alreadyAdded = existingNames.contains(preset.name)
                        Button {
                            if !alreadyAdded {
                                viewModel.addPresetMetric(preset)
                            }
                        } label: {
                            HStack {
                                Text(preset.icon)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.subheadline)
                                        .foregroundStyle(alreadyAdded ? .secondary : .primary)
                                    Text("\(preset.trackingType.displayName) · \(preset.unit)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if alreadyAdded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.primary)
                                } else {
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                        }
                        .disabled(alreadyAdded)
                    }
                } header: {
                    Text("\(viewModel.selectedCategory.displayName) Presets")
                }
            }
            .navigationTitle("Add Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MetricListView(
            viewModel: SampleData.makeMetricsViewModel(),
            category: .onCourse
        )
    }
}

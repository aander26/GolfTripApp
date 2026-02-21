import SwiftUI

struct MetricDetailView: View {
    @Bindable var viewModel: MetricsViewModel
    let metric: Metric

    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 14) {
                    Text(metric.icon)
                        .font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.name)
                            .font(.title2.bold())
                        HStack(spacing: 8) {
                            Text(metric.category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.primaryLight)
                                .clipShape(Capsule())
                            Text(metric.trackingType.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.background)
                                .clipShape(Capsule())
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            // Leaderboard
            Section("Leaderboard") {
                let standings = viewModel.standings(for: metric.id)
                if standings.isEmpty || standings.allSatisfy({ $0.total == 0 }) {
                    Text("No entries yet. Tap + to log values.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                        HStack(spacing: 12) {
                            positionBadge(index + 1)

                            Text(standing.player.initials)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(standing.player.avatarColor.color)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 1) {
                                Text(standing.player.name)
                                    .font(.subheadline)
                                Text("\(standing.entryCount) entries")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text("\(standing.total, specifier: standing.total == standing.total.rounded() ? "%.0f" : "%.1f")\(metric.formattedUnit)")
                                .font(.headline)
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }

            // Related Bets
            let relatedBets = viewModel.currentTrip?.bets(forMetric: metric.id) ?? []
            if !relatedBets.isEmpty {
                Section("Challenges") {
                    ForEach(relatedBets) { bet in
                        SideBetCardView(bet: bet, viewModel: viewModel)
                    }
                }
            }

            // Recent Entries
            Section("Recent Entries") {
                let entries = viewModel.recentEntries(for: metric.id)
                if entries.isEmpty {
                    Text("No entries yet")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.member?.name ?? "Unknown")
                                    .font(.subheadline)
                                Text(entry.formattedDate)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !entry.notes.isEmpty {
                                    Text(entry.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            Text("\(entry.formattedValue)\(metric.formattedUnit)")
                                .font(.subheadline.bold())
                                .foregroundStyle(Theme.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteEntry(entry.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(metric.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.selectedMetric = metric
                    viewModel.showingLogEntry = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }
        }
    }

    @ViewBuilder
    private func positionBadge(_ position: Int) -> some View {
        switch position {
        case 1:
            Image(systemName: "medal.fill")
                .foregroundStyle(.yellow)
                .frame(width: 24)
        case 2:
            Image(systemName: "medal.fill")
                .foregroundStyle(.gray)
                .frame(width: 24)
        case 3:
            Image(systemName: "medal.fill")
                .foregroundStyle(.brown)
                .frame(width: 24)
        default:
            Text("\(position)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 24)
        }
    }
}

#Preview {
    NavigationStack {
        MetricDetailView(
            viewModel: SampleData.makeMetricsViewModel(),
            metric: Metric.presetOnCourse[0]
        )
    }
}

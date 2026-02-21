import SwiftUI

struct SideGamesView: View {
    @Bindable var viewModel: SideGameViewModel
    @Bindable var metricsViewModel: MetricsViewModel
    @State private var selectedSection = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented picker
                Picker("Section", selection: $selectedSection) {
                    Text("Games").tag(0)
                    Text("On-Course").tag(1)
                    Text("Off-Course").tag(2)
                    Text("Challenges").tag(3)
                    Text("Results").tag(4)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content
                switch selectedSection {
                case 0:
                    classicSideGamesContent
                case 1:
                    MetricListView(
                        viewModel: metricsViewModel,
                        category: .onCourse
                    )
                case 2:
                    MetricListView(
                        viewModel: metricsViewModel,
                        category: .offCourse
                    )
                case 3:
                    sideBetsContent
                case 4:
                    SettlementView(trip: viewModel.currentTrip)
                default:
                    classicSideGamesContent
                }
            }
            .navigationTitle("Side Games")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedSection < 4 {
                    Menu {
                        switch selectedSection {
                        case 0:
                            Button {
                                viewModel.showingCreateGame = true
                            } label: {
                                Label("New Side Game", systemImage: "flag.checkered")
                            }
                        case 1:
                            Button {
                                metricsViewModel.newMetricCategory = .onCourse
                                metricsViewModel.showingAddMetric = true
                            } label: {
                                Label("Add Stat", systemImage: "plus.circle")
                            }
                            Button {
                                metricsViewModel.selectedCategory = .onCourse
                                metricsViewModel.showingPresetPicker = true
                            } label: {
                                Label("Add from Presets", systemImage: "list.bullet")
                            }
                        case 2:
                            Button {
                                metricsViewModel.newMetricCategory = .offCourse
                                metricsViewModel.showingAddMetric = true
                            } label: {
                                Label("Add Stat", systemImage: "plus.circle")
                            }
                            Button {
                                metricsViewModel.selectedCategory = .offCourse
                                metricsViewModel.showingPresetPicker = true
                            } label: {
                                Label("Add from Presets", systemImage: "list.bullet")
                            }
                        case 3:
                            Button {
                                metricsViewModel.showingCreateBet = true
                            } label: {
                                Label("New Challenge", systemImage: "trophy")
                            }
                        default:
                            EmptyView()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateGame) {
                CreateSideGameView(viewModel: viewModel)
            }
            .sheet(isPresented: $metricsViewModel.showingAddMetric) {
                AddMetricSheet(viewModel: metricsViewModel)
            }
            .sheet(isPresented: $metricsViewModel.showingLogEntry) {
                LogEntrySheet(viewModel: metricsViewModel)
            }
            .sheet(isPresented: $metricsViewModel.showingCreateBet) {
                CreateSideBetView(viewModel: metricsViewModel)
            }
            .sheet(isPresented: $metricsViewModel.showingPresetPicker) {
                PresetPickerSheet(viewModel: metricsViewModel)
            }
        }
    }

    // MARK: - Classic Side Games (original)

    @ViewBuilder
    private var classicSideGamesContent: some View {
        if viewModel.activeSideGames.isEmpty && viewModel.completedSideGames.isEmpty {
            emptySideGames
        } else {
            sideGamesList
        }
    }

    private var emptySideGames: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "flag.checkered")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("No Side Games")
                .font(.title2)
                .fontWeight(.bold)

            Text("Add side games to track skins, nassau, closest to pin, and more.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                viewModel.showingCreateGame = true
            } label: {
                Label("Add Side Game", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(BoldPrimaryButtonStyle())

            Spacer()
        }
    }

    private var sideGamesList: some View {
        List {
            if !viewModel.activeSideGames.isEmpty {
                Section("Active") {
                    ForEach(viewModel.activeSideGames) { game in
                        NavigationLink {
                            SideGameDetailView(viewModel: viewModel, game: game)
                        } label: {
                            SideGameRowView(game: game, trip: viewModel.currentTrip)
                        }
                    }
                }
            }

            if !viewModel.completedSideGames.isEmpty {
                Section("Completed") {
                    ForEach(viewModel.completedSideGames) { game in
                        NavigationLink {
                            SideGameDetailView(viewModel: viewModel, game: game)
                        } label: {
                            SideGameRowView(game: game, trip: viewModel.currentTrip)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Challenges

    @ViewBuilder
    private var sideBetsContent: some View {
        if metricsViewModel.activeBets.isEmpty && metricsViewModel.completedBets.isEmpty {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "trophy")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.primary)

                Text("No Challenges")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Create challenges on any tracked metric.\nWho has the most birdies? Fewest beers? You decide.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button {
                    metricsViewModel.showingCreateBet = true
                } label: {
                    Label("Create Challenge", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                }
                .buttonStyle(BoldPrimaryButtonStyle())

                Spacer()
            }
        } else {
            List {
                if !metricsViewModel.activeBets.isEmpty {
                    Section("Active Challenges") {
                        ForEach(metricsViewModel.activeBets) { bet in
                            SideBetCardView(
                                bet: bet,
                                viewModel: metricsViewModel
                            )
                        }
                    }
                }
                if !metricsViewModel.completedBets.isEmpty {
                    Section("Settled") {
                        ForEach(metricsViewModel.completedBets) { bet in
                            SideBetCardView(
                                bet: bet,
                                viewModel: metricsViewModel
                            )
                        }
                    }
                }
            }
        }
    }
}

struct SideGameRowView: View {
    let game: SideGame
    let trip: Trip?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(game.type.rawValue)
                    .font(.headline)

                if game.isPotGame {
                    Text("POOL")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Spacer()

                if game.isPotGame {
                    Text("\(String(format: "%.0f", game.totalPool)) pts")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.primary)
                } else {
                    Text(game.stakesLabel)
                        .font(.subheadline)
                        .foregroundStyle(Theme.primary)
                }
            }

            HStack {
                Text("\(game.participantIds.count) players")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if game.isPotGame {
                    Text("\(String(format: "%.0f", game.stakes)) pts/player")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if game.hasResults {
                    Text("\(game.results.count) results")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if game.isPotResolved, let winnerId = game.potWinnerId,
                   let player = trip?.player(withId: winnerId) {
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(player.name)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let appState = SampleData.makeAppState()
    SideGamesView(
        viewModel: SideGameViewModel(appState: appState),
        metricsViewModel: MetricsViewModel(appState: appState)
    )
}

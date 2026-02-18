import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var viewModelsInitialized = false
    @State private var tripViewModel: TripViewModel?
    @State private var scorecardViewModel: ScorecardViewModel?
    @State private var leaderboardViewModel: LeaderboardViewModel?
    @State private var sideGameViewModel: SideGameViewModel?
    @State private var weatherViewModel: WeatherViewModel?
    @State private var warRoomViewModel: WarRoomViewModel?
    @State private var metricsViewModel: MetricsViewModel?
    @State private var spotifyViewModel: SpotifyPlaylistViewModel?

    var body: some View {
        Group {
            if !viewModelsInitialized {
                ProgressView()
                    .onAppear { initializeViewModels() }
            } else if let tripVM = tripViewModel,
                      let warRoomVM = warRoomViewModel,
                      let weatherVM = weatherViewModel,
                      let leaderboardVM = leaderboardViewModel,
                      let scorecardVM = scorecardViewModel,
                      let sideGameVM = sideGameViewModel,
                      let metricsVM = metricsViewModel,
                      let spotifyVM = spotifyViewModel {
                if appState.currentTrip != nil {
                    tripTabView(
                        tripVM: tripVM,
                        warRoomVM: warRoomVM,
                        weatherVM: weatherVM,
                        leaderboardVM: leaderboardVM,
                        scorecardVM: scorecardVM,
                        sideGameVM: sideGameVM,
                        metricsVM: metricsVM,
                        spotifyVM: spotifyVM
                    )
                } else {
                    TripListView(viewModel: tripVM)
                }
            } else {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private func tripTabView(
        tripVM: TripViewModel,
        warRoomVM: WarRoomViewModel,
        weatherVM: WeatherViewModel,
        leaderboardVM: LeaderboardViewModel,
        scorecardVM: ScorecardViewModel,
        sideGameVM: SideGameViewModel,
        metricsVM: MetricsViewModel,
        spotifyVM: SpotifyPlaylistViewModel
    ) -> some View {
        TabView(selection: $selectedTab) {
            Tab("War Room", systemImage: "mappin.and.ellipse", value: 0) {
                WarRoomView(viewModel: warRoomVM, weatherViewModel: weatherVM, spotifyViewModel: spotifyVM)
            }

            Tab("Leaderboard", systemImage: "trophy.fill", value: 1) {
                LeaderboardView(viewModel: leaderboardVM)
            }

            Tab("Scorecard", systemImage: "square.grid.3x3.fill", value: 2) {
                ScorecardView(viewModel: scorecardVM)
            }

            Tab("Side Games", systemImage: "dollarsign.circle.fill", value: 3) {
                SideGamesView(viewModel: sideGameVM, metricsViewModel: metricsVM)
            }

            Tab("Trip", systemImage: "figure.golf", value: 4) {
                TripDetailView(viewModel: tripVM)
            }
        }
        .tint(Theme.primary)
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor(Theme.backgroundDark)
            // Active tab: emerald-400
            let activeColor = UIColor(Theme.primary)
            tabBarAppearance.stackedLayoutAppearance.selected.iconColor = activeColor
            tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: activeColor]
            // Inactive tab: gray-500
            let inactiveColor = UIColor(Theme.textSecondary)
            tabBarAppearance.stackedLayoutAppearance.normal.iconColor = inactiveColor
            tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor]
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

    private func initializeViewModels() {
        tripViewModel = TripViewModel(appState: appState)
        scorecardViewModel = ScorecardViewModel(appState: appState)
        leaderboardViewModel = LeaderboardViewModel(appState: appState)
        sideGameViewModel = SideGameViewModel(appState: appState)
        weatherViewModel = WeatherViewModel(appState: appState)
        warRoomViewModel = WarRoomViewModel(appState: appState)
        metricsViewModel = MetricsViewModel(appState: appState)
        spotifyViewModel = SpotifyPlaylistViewModel(appState: appState)
        viewModelsInitialized = true
    }
}

#Preview("With Trip") {
    MainTabView()
        .environment(SampleData.makeAppState())
        .modelContainer(SampleData.previewContainer)
}

#Preview("No Trip") {
    MainTabView()
        .environment(SampleData.makeEmptyAppState())
        .modelContainer(SampleData.previewContainer)
}

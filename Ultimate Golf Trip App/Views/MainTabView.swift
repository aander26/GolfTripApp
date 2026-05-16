import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    /// Persist the selected tab across app launches so users mid-round don't lose context when
    /// the phone locks. SceneStorage is scoped to the scene (window), survives backgrounding,
    /// and is wiped on app delete — exactly the lifecycle we want.
    @SceneStorage("mainTabSelectedTab") private var selectedTab: Int = 0
    /// Track whether selectedTab was already set this launch — used to apply DEBUG overrides
    /// once without clobbering the persisted value on subsequent renders.
    @State private var didApplyLaunchOverride = false
    @State private var viewModelsInitialized = false
    @State private var tripViewModel: TripViewModel?
    @State private var scorecardViewModel: ScorecardViewModel?
    @State private var leaderboardViewModel: LeaderboardViewModel?
    @State private var warRoomViewModel: WarRoomViewModel?
    @State private var challengesViewModel: ChallengesViewModel?

    var body: some View {
        Group {
            if !viewModelsInitialized {
                ProgressView()
                    .onAppear {
                        initializeViewModels()
                        applyLaunchOverridesIfNeeded()
                    }
            } else if let tripVM = tripViewModel,
                      let warRoomVM = warRoomViewModel,
                      let leaderboardVM = leaderboardViewModel,
                      let scorecardVM = scorecardViewModel,
                      let challengesVM = challengesViewModel {
                if appState.currentTrip != nil {
                    tripTabView(
                        tripVM: tripVM,
                        warRoomVM: warRoomVM,
                        leaderboardVM: leaderboardVM,
                        scorecardVM: scorecardVM,
                        challengesVM: challengesVM
                    )
                } else {
                    TripListView(viewModel: tripVM)
                }
            } else {
                ProgressView()
            }
        }
    }

    /// Apply launch-time overrides (DEBUG screenshot tab arg) exactly once per launch so
    /// the persisted @SceneStorage value isn't clobbered on every render.
    private func applyLaunchOverridesIfNeeded() {
        guard !didApplyLaunchOverride else { return }
        didApplyLaunchOverride = true
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let idx = args.firstIndex(of: "-screenshotTab"),
           idx + 1 < args.count,
           let tab = Int(args[idx + 1]) {
            selectedTab = tab
        }
        #endif
    }

    @ViewBuilder
    private func tripTabView(
        tripVM: TripViewModel,
        warRoomVM: WarRoomViewModel,
        leaderboardVM: LeaderboardViewModel,
        scorecardVM: ScorecardViewModel,
        challengesVM: ChallengesViewModel
    ) -> some View {
        TabView(selection: $selectedTab) {
            Tab("War Room", systemImage: "mappin.and.ellipse", value: 0) {
                WarRoomView(
                    viewModel: warRoomVM,
                    leaderboardViewModel: leaderboardVM,
                    challengesViewModel: challengesVM,
                    selectedTab: $selectedTab
                )
            }

            Tab("Leaderboard", systemImage: "trophy.fill", value: 1) {
                LeaderboardView(viewModel: leaderboardVM)
            }

            Tab("Scorecard", systemImage: "square.grid.3x3.fill", value: 2) {
                ScorecardView(viewModel: scorecardVM)
            }

            Tab("Challenges", systemImage: "trophy.circle.fill", value: 3) {
                SideGamesView(challengesViewModel: challengesVM)
            }

            Tab("Trip", systemImage: "figure.golf", value: 4) {
                TripDetailView(viewModel: tripVM)
            }
        }
        .tint(Theme.primary)
        .toolbarBackground(Theme.backgroundDark, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .overlay(alignment: .top) {
            if appState.lastSyncFailed {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.icloud")
                        .font(.caption)
                    Text(appState.lastSyncError ?? "Sync issue — check your connection.")
                        .font(.caption)
                    Spacer()
                    Button {
                        appState.lastSyncFailed = false
                        Task { await appState.syncWithCloud() }
                    } label: {
                        Text("Retry")
                            .font(.caption.bold())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.red.opacity(0.9))
                .foregroundStyle(.white)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.lastSyncFailed)
    }

    private func initializeViewModels() {
        tripViewModel = TripViewModel(appState: appState)
        scorecardViewModel = ScorecardViewModel(appState: appState)
        leaderboardViewModel = LeaderboardViewModel(appState: appState)
        warRoomViewModel = WarRoomViewModel(appState: appState)
        challengesViewModel = ChallengesViewModel(appState: appState)

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

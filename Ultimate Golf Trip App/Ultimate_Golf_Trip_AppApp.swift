import SwiftUI
import SwiftData

@main
struct Ultimate_Golf_Trip_AppApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [Trip.self, UserProfile.self])
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await appState.checkiCloudStatus()
                    if appState.iCloudAvailable {
                        await appState.syncWithCloud()
                    }
                }
            }
        }
    }
}

/// Injects the SwiftData ModelContext into AppState on first appear,
/// then displays the main ContentView.
struct AppBootstrapView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ContentView()
            .onAppear {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-screenshots") {
                    // Load sample data for App Store screenshots
                    let sample = SampleData.makeAppState()
                    appState.currentUser = sample.currentUser
                    appState.trips = sample.trips
                    appState.currentTrip = sample.currentTrip
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    return
                }
                #endif
                if appState.modelContext == nil {
                    appState.modelContext = modelContext
                    UserDefaultsMigrator.migrateIfNeeded(context: modelContext)
                    appState.loadTrips()
                    appState.loadUserProfile()

                    // Check iCloud availability and do initial sync
                    Task {
                        await appState.checkiCloudStatus()
                        if appState.iCloudAvailable {
                            await appState.syncWithCloud()
                        }
                    }
                }
            }
    }
}

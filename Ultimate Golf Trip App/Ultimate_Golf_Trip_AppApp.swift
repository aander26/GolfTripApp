import SwiftUI
import SwiftData
import CloudKit
import UIKit

@main
struct Ultimate_Golf_Trip_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    /// Local-only SwiftData container. CloudKit sync is handled manually via CloudKitService
    /// (not via SwiftData's built-in NSPersistentCloudKitContainer, which requires all
    /// attributes to be optional and all relationships to have inverses).
    let modelContainer: ModelContainer = {
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: Trip.self, UserProfile.self, configurations: config)
        } catch {
            // If the schema migration fails, wipe the store and retry so the app
            // can at least launch instead of crashing. Data will re-sync from CloudKit.
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            // Also remove the WAL/SHM sidecar files if present
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")
            try? FileManager.default.removeItem(at: walURL)
            try? FileManager.default.removeItem(at: shmURL)
            do {
                return try ModelContainer(for: Trip.self, UserProfile.self, configurations: config)
            } catch {
                fatalError("Could not create ModelContainer even after resetting store: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environment(appState)
                .preferredColorScheme(.light)
                .onAppear {
                    // Share appState with the delegate so it can trigger pulls
                    appDelegate.appState = appState
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name.CKAccountChanged)) { _ in
                    Task {
                        await appState.checkiCloudStatus()
                    }
                }
        }
        .modelContainer(modelContainer)
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

// MARK: - AppDelegate (Remote Notification Handling)

class AppDelegate: NSObject, UIApplicationDelegate {
    /// Set by the App struct so the delegate can trigger pulls.
    @MainActor var appState: AppState?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register for remote notifications (CloudKit silent pushes)
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // CloudKit handles token registration automatically
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Silent push registration failed — sync will still work via polling on foreground
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Check if this is a CloudKit notification
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard notification?.subscriptionID?.hasPrefix("trip_") == true else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            await appState?.handleRemoteNotification()
            completionHandler(.newData)
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
                    let sample = SampleData.makeAppState()
                    appState.currentUser = sample.currentUser
                    appState.trips = sample.trips
                    appState.currentTrip = sample.currentTrip
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-qatest") {
                    let qa = QATestData.makeAppState(tripIndex: 0)
                    appState.currentUser = qa.currentUser
                    appState.trips = qa.trips
                    appState.currentTrip = qa.currentTrip
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-qatest2") {
                    let qa = QATestData.makeAppState(tripIndex: 1)
                    appState.currentUser = qa.currentUser
                    appState.trips = qa.trips
                    appState.currentTrip = qa.currentTrip
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                    return
                }
                #endif
                if appState.modelContext == nil {
                    appState.modelContext = modelContext
                    UserDefaultsMigrator.migrateIfNeeded(context: modelContext)
                    appState.loadTrips()
                    appState.loadUserProfile()

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

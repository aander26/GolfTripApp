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
        let schema = Schema([Trip.self, UserProfile.self])
        let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        // First attempt: open the existing store (handles lightweight migrations automatically)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            print("⚠️ ModelContainer failed on first attempt: \(error)")
            print("⚠️ Attempting store reset — data will re-sync from CloudKit.")

            // Back up the old store before deleting so data isn't irrecoverably lost
            let storeURL = config.url
            let backupURL = storeURL.deletingLastPathComponent()
                .appendingPathComponent("default-backup-\(Int(Date().timeIntervalSince1970)).store")
            try? FileManager.default.copyItem(at: storeURL, to: backupURL)

            // Remove the store and its sidecar files
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))

            // Second attempt with a fresh store
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                // Last resort: try an in-memory store so the app can at least launch
                // and re-sync from CloudKit rather than crashing in a loop
                print("🔴 ModelContainer still failed after reset: \(error)")
                print("🔴 Falling back to in-memory store. Data will re-sync from CloudKit.")
                let inMemoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none
                )
                do {
                    return try ModelContainer(for: schema, configurations: inMemoryConfig)
                } catch {
                    fatalError("Could not create ModelContainer even in-memory: \(error)")
                }
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environment(appState)
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
    @State private var showMigrationError = false

    var body: some View {
        ContentView()
            .alert("Data Migration Issue", isPresented: $showMigrationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Some trip data from a previous version couldn't be imported. Your new data is safe, but older trips may need to be re-synced from iCloud.")
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MigrationFailed"))) { _ in
                showMigrationError = true
            }
            .alert("Error", isPresented: Binding(
                get: { appState.errorMessage != nil },
                set: { if !$0 { appState.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(appState.errorMessage ?? "")
            }
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

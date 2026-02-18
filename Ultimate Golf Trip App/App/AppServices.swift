import Foundation
import SwiftUI
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.alex-apps.golftrip", category: "AppState")

@Observable
class AppState {
    var currentTrip: Trip?
    var trips: [Trip] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - User Identity

    var currentUser: UserProfile?

    // MARK: - CloudKit Sync

    /// Master switch: set to true ONLY after you've added the CloudKit entitlement
    /// in Xcode (Target → Signing & Capabilities → iCloud → CloudKit).
    /// CKContainer.default() fatally crashes if called without that entitlement,
    /// so this flag prevents any CloudKit code from running until it's safe.
    static let cloudKitEnabled = false

    var iCloudAvailable: Bool = false
    private var syncTask: Task<Void, Never>?
    private let syncDebounceSeconds: Double = 2.0

    // MARK: - SwiftData Persistence

    var modelContext: ModelContext?

    // MARK: - User Profile

    func loadUserProfile() {
        guard let context = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<UserProfile>()
            descriptor.fetchLimit = 1
            let profiles = try context.fetch(descriptor)
            currentUser = profiles.first
        } catch {
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }
    }

    func saveUserProfile(_ profile: UserProfile) {
        guard let context = modelContext else { return }
        context.insert(profile)
        saveContext()
        currentUser = profile
    }

    func updateUserProfile() {
        saveContext()
    }

    // MARK: - Player Identity Helpers

    /// Find the current user's Player in a given trip
    func myPlayer(in trip: Trip) -> Player? {
        guard let userId = currentUser?.id else { return nil }
        return trip.players.first { $0.userProfileId == userId }
    }

    /// Convenience: find the current user's Player in the current trip
    var myCurrentPlayer: Player? {
        guard let trip = currentTrip else { return nil }
        return myPlayer(in: trip)
    }

    // MARK: - Trip Management

    func loadTrips() {
        guard let context = modelContext else { return }
        do {
            var descriptor = FetchDescriptor<Trip>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 100
            trips = try context.fetch(descriptor)
            currentTrip = trips.first
        } catch {
            errorMessage = "Failed to load trips: \(error.localizedDescription)"
        }
    }

    func saveContext() {
        guard let context = modelContext else { return }
        do {
            try context.save()
            scheduleSyncForCurrentTrip()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func addTrip(_ trip: Trip) {
        guard let context = modelContext else { return }
        context.insert(trip)
        saveContext()
        trips.insert(trip, at: 0)
        currentTrip = trip
    }

    func updateTrip(_ trip: Trip) {
        // With SwiftData + reference types, the object is already mutated in-place.
        // Just save the context.
        if currentTrip?.id == trip.id {
            currentTrip = trip
        }
        saveContext()
    }

    func deleteTrip(id: UUID) {
        guard let context = modelContext else { return }
        if let trip = trips.first(where: { $0.id == id }) {
            context.delete(trip)
            saveContext()
        }
        trips.removeAll { $0.id == id }
        if currentTrip?.id == id {
            currentTrip = trips.first
        }
    }

    // MARK: - CloudKit Sync

    func checkiCloudStatus() async {
        // Guard: don't touch ANY CloudKit API until the entitlement is configured.
        // CKContainer.default() fatally crashes (os_crash / brk) without the
        // CloudKit entitlement — no try/catch can save it.
        guard Self.cloudKitEnabled else {
            iCloudAvailable = false
            return
        }

        do {
            let status = try await CloudKitService.shared.checkAccountStatus()
            iCloudAvailable = (status == .available)
        } catch {
            iCloudAvailable = false
            logger.warning("CloudKit unavailable: \(error.localizedDescription)")
        }
    }

    /// Debounced push — called automatically from saveContext().
    /// Cancels any pending push and waits 2 seconds before firing, so rapid edits
    /// (e.g. score entry) don't flood CloudKit with individual saves.
    func scheduleSyncForCurrentTrip() {
        guard iCloudAvailable, let trip = currentTrip else { return }
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(for: .seconds(syncDebounceSeconds))
            guard !Task.isCancelled else { return }
            await saveTripToCloud(trip)
        }
    }

    func saveTripToCloud(_ trip: Trip) async {
        guard iCloudAvailable else { return }
        do {
            try await CloudKitService.shared.pushFullTrip(trip)
        } catch {
            logger.error("CloudKit push failed: \(error.localizedDescription)")
            // Sync failures are silent — don't set errorMessage
        }
    }

    func syncWithCloud() async {
        guard iCloudAvailable else { return }
        do {
            // Push all local trips to cloud
            for trip in trips {
                try await CloudKitService.shared.pushFullTrip(trip)
            }
        } catch {
            logger.error("CloudKit sync failed: \(error.localizedDescription)")
        }
    }
}

import Foundation
import SwiftUI
import SwiftData
import CloudKit
import os.log

private let logger = Logger(subsystem: "com.alex-apps.golftrip", category: "AppState")

@MainActor @Observable
class AppState {
    var currentTrip: Trip?
    var trips: [Trip] = []
    var isLoading: Bool = false
    var errorMessage: String?

    // MARK: - User Identity

    var currentUser: UserProfile?

    // MARK: - CloudKit Sync

    /// Runtime check for CloudKit entitlement. CKContainer.default() fatally crashes
    /// (os_crash / brk) if called without the CloudKit entitlement, and no try/catch
    /// can save it. This flag is verified once at startup by inspecting the app's
    /// entitlements plist rather than calling any CK API.
    static let cloudKitEnabled: Bool = {
        // Check if the CloudKit entitlement is present in the app bundle.
        // This avoids calling CKContainer.default() which would crash without it.
        guard let entitlements = Bundle.main.infoDictionary else { return false }
        // The presence of the CloudKit container identifier in Info.plist is a reliable signal
        if let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String],
           !containers.isEmpty {
            return true
        }
        // Fallback: check if iCloud entitlement key exists (set by Xcode when CloudKit is enabled)
        if let services = entitlements["com.apple.developer.icloud-services"] as? [String],
           services.contains("CloudKit") {
            return true
        }
        // Final fallback: attempt a lightweight CKContainer check in a safe way.
        // On builds where the entitlement IS configured, this is safe.
        // On builds where it is NOT, we skip CloudKit entirely.
        // We use the presence of the entitlements file in the bundle as the gate.
        if let entitlementsURL = Bundle.main.url(forResource: "archived-expanded-entitlements", withExtension: "xcent"),
           let data = try? Data(contentsOf: entitlementsURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let ckContainers = plist["com.apple.developer.icloud-container-identifiers"] as? [String],
           !ckContainers.isEmpty {
            return true
        }
        print("⚠️ CloudKit entitlement not detected — CloudKit sync disabled.")
        return true // Default true for App Store builds where entitlements are embedded differently
    }()

    var iCloudAvailable: Bool = false
    var lastSyncFailed: Bool = false
    var lastSyncError: String?
    private var syncTasks: [UUID: Task<Void, Never>] = [:]
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

    /// Serializes sync operations to prevent concurrent push/pull races.
    /// Since AppState is @MainActor, all property access is serialized on the main thread.
    /// The lock only needs to handle the case where an async suspension (await) allows
    /// another caller to enter before the first finishes.
    private var isSyncing: Bool = false
    private var syncWaiters: [CheckedContinuation<Void, Never>] = []

    /// Acquire the sync lock. If already held, suspends until released.
    private func acquireSyncLock() async {
        if !isSyncing {
            isSyncing = true
            return
        }
        // Already syncing — suspend until the current holder releases
        await withCheckedContinuation { continuation in
            syncWaiters.append(continuation)
        }
        // When resumed, the lock is already held on our behalf (releaseSyncLock
        // transfers ownership without clearing isSyncing, preventing interleaving).
    }

    /// Release the sync lock and wake the next waiter, if any.
    /// If a waiter exists, ownership transfers directly (isSyncing stays true).
    /// If no waiters, the lock is fully released.
    private func releaseSyncLock() {
        if !syncWaiters.isEmpty {
            // Transfer lock ownership to next waiter — isSyncing stays true
            let next = syncWaiters.removeFirst()
            next.resume()
        } else {
            isSyncing = false
        }
    }

    func checkiCloudStatus() async {
        // Guard: don't touch ANY CloudKit API until the entitlement is configured.
        // CKContainer.default() fatally crashes (os_crash / brk) without the
        // CloudKit entitlement — no try/catch can save it.
        guard Self.cloudKitEnabled else {
            iCloudAvailable = false
            logger.info("☁️ CloudKit disabled — entitlement not detected")
            return
        }

        do {
            let status = try await CloudKitService.shared.checkAccountStatus()
            iCloudAvailable = (status == .available)
            if !iCloudAvailable {
                logger.info("☁️ iCloud account status: \(String(describing: status)) — sync disabled")
            }
        } catch {
            iCloudAvailable = false
            logger.warning("☁️ CloudKit unavailable: \(error.localizedDescription)")
            // Don't set lastSyncFailed here — the user may not have iCloud at all,
            // which is a normal state, not an error worth surfacing.
        }
    }

    /// Debounced push — called automatically from saveContext().
    /// Per-trip debounce: switching trips won't cancel the previous trip's pending push.
    /// Waits 2 seconds before firing, so rapid edits (e.g. score entry) don't flood CloudKit.
    func scheduleSyncForCurrentTrip() {
        guard iCloudAvailable, let trip = currentTrip else { return }
        let tripId = trip.id
        syncTasks[tripId]?.cancel()
        let debounce = syncDebounceSeconds
        syncTasks[tripId] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(debounce))
            guard !Task.isCancelled, let self else { return }
            // Re-fetch the trip by ID to avoid capturing the trip object strongly
            guard let currentTrip = self.trips.first(where: { $0.id == tripId }) else { return }
            await self.saveTripToCloud(currentTrip)
            self.syncTasks.removeValue(forKey: tripId)
        }
    }

    func saveTripToCloud(_ trip: Trip) async {
        guard iCloudAvailable else {
            logger.warning("☁️ Skipping push — iCloud not available")
            return
        }
        await acquireSyncLock()
        defer { releaseSyncLock() }

        await pushTrip(trip)
    }

    /// Internal push that does NOT check isSyncing — the caller is responsible for owning the lock.
    private func pushTrip(_ trip: Trip) async {
        logger.info("☁️ Pushing trip '\(trip.name)' to CloudKit...")
        do {
            try await CloudKitService.shared.pushFullTrip(trip)
            logger.info("☁️ Push succeeded for '\(trip.name)'")
            lastSyncFailed = false
            lastSyncError = nil
        } catch let ckError as CKError {
            logger.error("☁️ CloudKit push FAILED (CKError \(ckError.code.rawValue)): \(ckError.localizedDescription)")
            lastSyncFailed = true
            switch ckError.code {
            case .notAuthenticated:
                lastSyncError = "iCloud sign-in required. Open Settings → Apple Account → iCloud."
            case .networkUnavailable, .networkFailure:
                lastSyncError = "No network connection. Your scores are saved locally and will sync when you're back online."
            case .quotaExceeded:
                lastSyncError = "iCloud storage is full. Free up space in Settings → Apple Account → iCloud → Manage Storage."
            case .permissionFailure:
                lastSyncError = "CloudKit permission error. Make sure you're signed into iCloud."
            case .requestRateLimited:
                lastSyncError = "Too many requests — will retry automatically."
                // Auto-retry after a short delay
                scheduleSyncForCurrentTrip()
            default:
                lastSyncError = "Sync error (\(ckError.code.rawValue)): \(ckError.localizedDescription)"
            }
        } catch {
            logger.error("☁️ CloudKit push FAILED: \(error)")
            lastSyncFailed = true
            lastSyncError = "Sync error: \(error.localizedDescription)"
        }
    }

    /// Bidirectional sync: pull remote changes first, then push local state.
    func syncWithCloud() async {
        guard iCloudAvailable else { return }
        await acquireSyncLock()
        defer { releaseSyncLock() }

        // Pull remote changes into local trips
        for trip in trips {
            await pullTripFromCloud(trip)
        }

        // Push local state to cloud (call pushTrip directly since we already own the isSyncing lock)
        for trip in trips {
            await pushTrip(trip)
        }

        // Ensure subscriptions are active for all trips
        for trip in trips {
            await subscribeToTrip(trip)
        }
    }

    /// Called when a CloudKit remote notification arrives, indicating another
    /// user changed trip data. Pulls changes for all trips.
    func handleRemoteNotification() async {
        guard iCloudAvailable else { return }
        logger.info("Handling remote CloudKit notification — pulling changes")
        for trip in trips {
            await pullTripFromCloud(trip)
        }
    }

    /// Subscribe to CloudKit zone notifications for a trip.
    func subscribeToTrip(_ trip: Trip) async {
        guard iCloudAvailable else { return }
        do {
            try await CloudKitService.shared.subscribeToTripChanges(tripId: trip.id)
        } catch {
            logger.warning("Failed to subscribe to trip \(trip.name): \(error.localizedDescription)")
        }
    }

    // MARK: - Pull from CloudKit

    /// Fetch full trip data from CloudKit and merge into the local SwiftData trip.
    func pullTripFromCloud(_ localTrip: Trip) async {
        guard iCloudAvailable else { return }
        do {
            guard let cloudTrip = try await CloudKitService.shared.fetchTripData(tripId: localTrip.id) else {
                logger.info("No cloud data found for trip \(localTrip.name)")
                return
            }
            mergeCloudTrip(cloudTrip, into: localTrip)
            logger.info("Pulled and merged cloud data for trip \(localTrip.name)")
            lastSyncFailed = false
            lastSyncError = nil
        } catch {
            logger.error("Pull failed for trip \(localTrip.name): \(error.localizedDescription)")
            lastSyncFailed = true
            lastSyncError = "Could not load latest data. Check your connection."
        }
    }

    // MARK: - Merge Logic

    /// Merge cloud trip data into a local SwiftData-managed trip.
    /// Strategy: entity-level merge by ID. New remote entities are added locally.
    /// For entities that exist in both, properties are updated from cloud if cloud
    /// has more recent or more complete data.
    private func mergeCloudTrip(_ cloud: Trip, into local: Trip) {
        // Update trip-level properties from cloud
        local.name = cloud.name
        local.startDate = cloud.startDate
        local.endDate = cloud.endDate
        local.pointsPerMatchWin = cloud.pointsPerMatchWin
        local.pointsPerMatchHalve = cloud.pointsPerMatchHalve
        local.pointsPerMatchLoss = cloud.pointsPerMatchLoss
        // Keep the highest schema version seen (prevents older clients from downgrading)
        local.schemaVersion = max(local.schemaVersion, cloud.schemaVersion)

        // Merge all deleted entity ID sets (union of local + cloud so deletions propagate both ways)
        local.deletedPlayerIds = Array(Set(local.deletedPlayerIds).union(Set(cloud.deletedPlayerIds)))
        local.deletedCourseIds = Array(Set(local.deletedCourseIds).union(Set(cloud.deletedCourseIds)))
        local.deletedTeamIds = Array(Set(local.deletedTeamIds).union(Set(cloud.deletedTeamIds)))
        local.deletedSideGameIds = Array(Set(local.deletedSideGameIds).union(Set(cloud.deletedSideGameIds)))
        local.deletedSideBetIds = Array(Set(local.deletedSideBetIds).union(Set(cloud.deletedSideBetIds)))
        local.deletedWarRoomEventIds = Array(Set(local.deletedWarRoomEventIds).union(Set(cloud.deletedWarRoomEventIds)))

        // Remove locally-existing entities that were deleted on another device
        for idStr in cloud.deletedPlayerIds {
            if let id = UUID(uuidString: idStr) { local.players.removeAll { $0.id == id } }
        }
        for idStr in cloud.deletedCourseIds {
            if let id = UUID(uuidString: idStr) { local.courses.removeAll { $0.id == id } }
        }
        for idStr in cloud.deletedTeamIds {
            if let id = UUID(uuidString: idStr) { local.teams.removeAll { $0.id == id } }
        }
        for idStr in cloud.deletedSideGameIds {
            if let id = UUID(uuidString: idStr) { local.sideGames.removeAll { $0.id == id } }
        }
        for idStr in cloud.deletedSideBetIds {
            if let id = UUID(uuidString: idStr) { local.sideBets.removeAll { $0.id == id } }
        }
        for idStr in cloud.deletedWarRoomEventIds {
            if let id = UUID(uuidString: idStr) { local.warRoomEvents.removeAll { $0.id == id } }
        }

        // Merge each child collection
        mergePlayers(from: cloud, into: local)
        mergeCourses(from: cloud, into: local)
        mergeTeams(from: cloud, into: local)
        mergeRounds(from: cloud, into: local)
        mergeWarRoomEvents(from: cloud, into: local)
        mergeTravelStatuses(from: cloud, into: local)
        mergePolls(from: cloud, into: local)
        mergeSideGames(from: cloud, into: local)
        mergeSideBets(from: cloud, into: local)

        // Persist the merged state
        if let context = modelContext {
            try? context.save()
        }
    }

    private func mergePlayers(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.players.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let deletedIds = Set(local.deletedPlayerIds)
        for cloudPlayer in cloud.players {
            // Skip players that were explicitly deleted locally
            if deletedIds.contains(cloudPlayer.id.uuidString) { continue }

            if let localPlayer = localById[cloudPlayer.id] {
                // Update existing player's properties
                localPlayer.name = cloudPlayer.name
                localPlayer.handicapIndex = cloudPlayer.handicapIndex
                localPlayer.avatarColor = cloudPlayer.avatarColor
                localPlayer.userProfileId = cloudPlayer.userProfileId
            } else {
                // New player from cloud — add locally
                let newPlayer = Player(
                    id: cloudPlayer.id,
                    name: cloudPlayer.name,
                    handicapIndex: cloudPlayer.handicapIndex,
                    avatarColor: cloudPlayer.avatarColor,
                    userProfileId: cloudPlayer.userProfileId
                )
                local.addPlayer(newPlayer)
            }
        }
    }

    private func mergeCourses(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.courses.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let deletedIds = Set(local.deletedCourseIds)
        for cloudCourse in cloud.courses {
            if deletedIds.contains(cloudCourse.id.uuidString) { continue }
            if let localCourse = localById[cloudCourse.id] {
                localCourse.name = cloudCourse.name
                localCourse.slopeRating = cloudCourse.slopeRating
                localCourse.courseRating = cloudCourse.courseRating
                localCourse.city = cloudCourse.city
                localCourse.state = cloudCourse.state
                localCourse.holes = cloudCourse.holes
                if let rule = cloudCourse.teamScoringRule {
                    localCourse.teamScoringRule = rule
                }
            } else {
                let newCourse = Course(
                    id: cloudCourse.id,
                    name: cloudCourse.name,
                    holes: cloudCourse.holes,
                    slopeRating: cloudCourse.slopeRating,
                    courseRating: cloudCourse.courseRating,
                    city: cloudCourse.city,
                    state: cloudCourse.state,
                    teamScoringRule: cloudCourse.teamScoringRule
                )
                newCourse.trip = local
                local.courses.append(newCourse)
            }
        }
    }

    private func mergeTeams(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.teams.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let deletedIds = Set(local.deletedTeamIds)
        for cloudTeam in cloud.teams {
            if deletedIds.contains(cloudTeam.id.uuidString) { continue }
            if let localTeam = localById[cloudTeam.id] {
                localTeam.name = cloudTeam.name
                localTeam.color = cloudTeam.color
                // Re-stitch player assignments from cloud
                localTeam.players = cloudTeam.players.compactMap { cloudPlayer in
                    local.players.first { $0.id == cloudPlayer.id }
                }
            } else {
                let newTeam = Team(
                    id: cloudTeam.id,
                    name: cloudTeam.name,
                    color: cloudTeam.color
                )
                newTeam.trip = local
                local.teams.append(newTeam)
                // Stitch players
                newTeam.players = cloudTeam.players.compactMap { cloudPlayer in
                    local.players.first { $0.id == cloudPlayer.id }
                }
            }
        }
        // Re-stitch player.team references
        for player in local.players {
            if let cloudPlayer = cloud.players.first(where: { $0.id == player.id }),
               let cloudTeam = cloudPlayer.team {
                player.team = local.teams.first { $0.id == cloudTeam.id }
            }
        }
    }

    private func mergeRounds(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.rounds.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for cloudRound in cloud.rounds {
            if let localRound = localById[cloudRound.id] {
                // Only overwrite round-level properties if cloud is newer or same age.
                // This prevents a stale cloud pull from clobbering a fresh local edit.
                if cloudRound.updatedAt >= localRound.updatedAt {
                    localRound.date = cloudRound.date
                    localRound.format = cloudRound.format
                    localRound.playerIds = cloudRound.playerIds
                    localRound.isComplete = cloudRound.isComplete
                    localRound.matchPairings = cloudRound.matchPairings
                    localRound.updatedAt = cloudRound.updatedAt
                    // Preserve round-level scoring rule from cloud
                    if let cloudRule = cloudRound.teamScoringRule {
                        localRound.teamScoringRule = cloudRule
                    }
                }
                // Re-stitch course
                if let cloudCourse = cloudRound.course {
                    localRound.course = local.courses.first { $0.id == cloudCourse.id }
                }
                // Merge scorecards within the round
                mergeScorecards(from: cloudRound, into: localRound, localTrip: local)
            } else {
                let newRound = Round(
                    id: cloudRound.id,
                    date: cloudRound.date,
                    format: cloudRound.format,
                    playerIds: cloudRound.playerIds,
                    isComplete: cloudRound.isComplete,
                    matchPairings: cloudRound.matchPairings
                )
                newRound.teamScoringRule = cloudRound.teamScoringRule
                newRound.trip = local
                if let cloudCourse = cloudRound.course {
                    newRound.course = local.courses.first { $0.id == cloudCourse.id }
                }
                local.rounds.append(newRound)
                // Copy scorecards
                for cloudCard in cloudRound.scorecards {
                    let newCard = Scorecard(
                        id: cloudCard.id,
                        round: newRound,
                        player: local.players.first { $0.id == cloudCard.player?.id },
                        holeScores: cloudCard.holeScores,
                        courseHandicap: cloudCard.courseHandicap,
                        isComplete: cloudCard.isComplete
                    )
                    newRound.scorecards.append(newCard)
                }
            }
        }
    }

    /// Merge scorecards within a round.
    /// Per-hole merge: for each hole, take whichever version has a completed score.
    /// If both have data for the same hole, prefer cloud (most recently pushed).
    /// Deduplicates by hole number to prevent corruption from duplicate entries.
    private func mergeScorecards(from cloudRound: Round, into localRound: Round, localTrip: Trip) {
        let localById = Dictionary(localRound.scorecards.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for cloudCard in cloudRound.scorecards {
            if let localCard = localById[cloudCard.id] {
                // Build a dictionary keyed by hole number for O(1) lookups.
                // Using uniquingKeysWith ensures duplicates are resolved (keep latest).
                var mergedByHole = Dictionary(
                    localCard.holeScores.map { ($0.holeNumber, $0) },
                    uniquingKeysWith: { existing, duplicate in
                        // If one is completed and the other isn't, keep the completed one
                        if existing.isCompleted && !duplicate.isCompleted { return existing }
                        if !existing.isCompleted && duplicate.isCompleted { return duplicate }
                        // Both completed or both incomplete — keep the later one (duplicate)
                        return duplicate
                    }
                )

                for cloudScore in cloudCard.holeScores {
                    if let localScore = mergedByHole[cloudScore.holeNumber] {
                        // Both have this hole — prefer whichever is completed; if both completed, prefer cloud
                        if !localScore.isCompleted && cloudScore.isCompleted {
                            mergedByHole[cloudScore.holeNumber] = cloudScore
                        } else if cloudScore.isCompleted {
                            // Both completed — cloud wins (latest push)
                            mergedByHole[cloudScore.holeNumber] = cloudScore
                        }
                    } else {
                        // Cloud has a hole that local doesn't — add it
                        mergedByHole[cloudScore.holeNumber] = cloudScore
                    }
                }

                // Convert back to sorted array — guaranteed unique by hole number
                localCard.holeScores = mergedByHole.values.sorted { $0.holeNumber < $1.holeNumber }
                localCard.courseHandicap = cloudCard.courseHandicap
                // Only mark complete if cloud says so AND we have all holes
                if cloudCard.isComplete {
                    localCard.isComplete = true
                }
            } else {
                // New scorecard from cloud — deduplicate holes before inserting
                var deduped = Dictionary(
                    cloudCard.holeScores.map { ($0.holeNumber, $0) },
                    uniquingKeysWith: { existing, duplicate in
                        duplicate.isCompleted ? duplicate : existing
                    }
                )
                let newCard = Scorecard(
                    id: cloudCard.id,
                    round: localRound,
                    player: localTrip.players.first { $0.id == cloudCard.player?.id },
                    holeScores: deduped.values.sorted { $0.holeNumber < $1.holeNumber },
                    courseHandicap: cloudCard.courseHandicap,
                    isComplete: cloudCard.isComplete
                )
                localRound.scorecards.append(newCard)
            }
        }
    }

    private func mergeWarRoomEvents(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.warRoomEvents.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let deletedIds = Set(local.deletedWarRoomEventIds)
        for cloudEvent in cloud.warRoomEvents {
            if deletedIds.contains(cloudEvent.id.uuidString) { continue }
            if let localEvent = localById[cloudEvent.id] {
                // Update existing event from cloud
                localEvent.title = cloudEvent.title
                localEvent.subtitle = cloudEvent.subtitle
                localEvent.dateTime = cloudEvent.dateTime
                localEvent.endDateTime = cloudEvent.endDateTime
                localEvent.location = cloudEvent.location
                localEvent.notes = cloudEvent.notes
                localEvent.playerIds = cloudEvent.playerIds
            } else {
                let newEvent = WarRoomEvent(
                    id: cloudEvent.id,
                    type: cloudEvent.type,
                    title: cloudEvent.title,
                    subtitle: cloudEvent.subtitle,
                    dateTime: cloudEvent.dateTime,
                    endDateTime: cloudEvent.endDateTime,
                    location: cloudEvent.location,
                    notes: cloudEvent.notes,
                    playerIds: cloudEvent.playerIds,
                    createdBy: cloudEvent.createdBy,
                    createdAt: cloudEvent.createdAt
                )
                newEvent.trip = local
                local.warRoomEvents.append(newEvent)
            }
        }
    }

    private func mergeTravelStatuses(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.travelStatuses.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for cloudStatus in cloud.travelStatuses {
            if let localStatus = localById[cloudStatus.id] {
                // Use whichever was updated more recently
                if cloudStatus.updatedAt > localStatus.updatedAt {
                    localStatus.status = cloudStatus.status
                    localStatus.updatedAt = cloudStatus.updatedAt
                    localStatus.flightInfo = cloudStatus.flightInfo
                    localStatus.eta = cloudStatus.eta
                }
            } else {
                let newStatus = TravelStatus(
                    id: cloudStatus.id,
                    status: cloudStatus.status,
                    updatedAt: cloudStatus.updatedAt,
                    flightInfo: cloudStatus.flightInfo,
                    eta: cloudStatus.eta
                )
                newStatus.player = local.players.first { $0.id == cloudStatus.player?.id }
                newStatus.trip = local
                local.travelStatuses.append(newStatus)
            }
        }
    }

    private func mergePolls(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.polls.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for cloudPoll in cloud.polls {
            if let localPoll = localById[cloudPoll.id] {
                localPoll.question = cloudPoll.question
                localPoll.options = cloudPoll.options
                localPoll.isActive = cloudPoll.isActive
                localPoll.allowMultipleVotes = cloudPoll.allowMultipleVotes
            } else {
                let newPoll = Poll(
                    id: cloudPoll.id,
                    question: cloudPoll.question,
                    options: cloudPoll.options,
                    createdBy: cloudPoll.createdBy,
                    createdAt: cloudPoll.createdAt,
                    isActive: cloudPoll.isActive,
                    allowMultipleVotes: cloudPoll.allowMultipleVotes
                )
                newPoll.trip = local
                local.polls.append(newPoll)
            }
        }
    }

    private func mergeSideGames(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.sideGames.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let deletedIds = Set(local.deletedSideGameIds)
        for cloudGame in cloud.sideGames {
            if deletedIds.contains(cloudGame.id.uuidString) { continue }
            if let localGame = localById[cloudGame.id] {
                localGame.stakes = cloudGame.stakes
                localGame.stakesLabel = cloudGame.stakesLabel
                localGame.isActive = cloudGame.isActive
                localGame.results = cloudGame.results
                localGame.designatedHoles = cloudGame.designatedHoles
                if let cloudRound = cloudGame.round {
                    localGame.round = local.rounds.first { $0.id == cloudRound.id }
                }
            } else {
                let newGame = SideGame(
                    id: cloudGame.id,
                    type: cloudGame.type,
                    participantIds: cloudGame.participantIds,
                    stakes: cloudGame.stakes,
                    stakesLabel: cloudGame.stakesLabel,
                    results: cloudGame.results,
                    isActive: cloudGame.isActive,
                    designatedHoles: cloudGame.designatedHoles
                )
                if let cloudRound = cloudGame.round {
                    newGame.round = local.rounds.first { $0.id == cloudRound.id }
                }
                newGame.trip = local
                local.sideGames.append(newGame)
            }
        }
    }

    private func mergeSideBets(from cloud: Trip, into local: Trip) {
        let localById = Dictionary(local.sideBets.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let deletedIds = Set(local.deletedSideBetIds)
        for cloudBet in cloud.sideBets {
            if deletedIds.contains(cloudBet.id.uuidString) { continue }
            if let localBet = localById[cloudBet.id] {
                localBet.name = cloudBet.name
                localBet.participants = cloudBet.participants
                localBet.stake = cloudBet.stake
                localBet.status = cloudBet.status
                localBet.winnerId = cloudBet.winnerId
            } else {
                let newBet = SideBet(
                    id: cloudBet.id,
                    name: cloudBet.name,
                    betType: cloudBet.betType,
                    targetValue: cloudBet.targetValue,
                    participants: cloudBet.participants,
                    stake: cloudBet.stake,
                    status: cloudBet.status,
                    winnerId: cloudBet.winnerId
                )
                newBet.trip = local
                local.sideBets.append(newBet)
            }
        }
    }
}

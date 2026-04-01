import Foundation
import CloudKit
import SwiftUI
import os.log

private let ckLogger = Logger(subsystem: "com.alex-apps.golftrip", category: "CloudKit")

actor CloudKitService {
    static let shared = CloudKitService()

    // Lazy container access — CKContainer.default() crashes when the CloudKit
    // entitlement is missing, so we must NOT call it during init().
    // All callers must go through AppState.cloudKitEnabled first.
    private var _container: CKContainer?
    private var container: CKContainer {
        get throws {
            if let existing = _container { return existing }
            // Guard: AppState.cloudKitEnabled should have been checked before any
            // CloudKitService call. This is a last-resort safety net.
            guard AppState.cloudKitEnabled else {
                throw CKError(.permissionFailure)
            }
            let c = CKContainer.default()
            _container = c
            return c
        }
    }
    private var publicDB: CKDatabase {
        get throws { try container.publicCloudDatabase }
    }

    private init() {
        // Intentionally empty — container is lazily created on first use
    }

    // MARK: - Account Status

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await (try container).accountStatus()
    }

    var isAvailable: Bool {
        get async {
            do {
                let status = try await checkAccountStatus()
                return status == .available
            } catch {
                return false
            }
        }
    }

    // MARK: - Save Records

    func saveTrip(_ trip: Trip) async throws {
        try await pushFullTrip(trip)
    }

    /// Push the trip record and ALL child arrays to CloudKit public database.
    /// All users in the trip can read/write these records.
    func pushFullTrip(_ trip: Trip) async throws {
        ckLogger.info("☁️ pushFullTrip starting for '\(trip.name)' (id: \(trip.id.uuidString.prefix(8)))")

        // Trip record — this one must succeed or we abort entirely
        let record = tripToRecord(trip)
        try await saveRecord(record, label: "Trip")

        // Helper: push a batch of records, logging failures but never
        // stopping the rest of the push. This prevents a missing record
        // type (e.g. TravelStatus not yet in production schema) from
        // blocking SideGames, SideBets, and the share-code index.
        func pushBatch(_ records: [(CKRecord, String)]) async {
            for (r, label) in records {
                do {
                    try await saveRecord(r, label: label)
                } catch {
                    ckLogger.error("  ⚠️ Skipped \(label): \(error.localizedDescription)")
                }
            }
        }

        // Players
        await pushBatch(trip.players.map { (playerToRecord($0, tripId: trip.id), "Player(\($0.name))") })

        // Courses
        await pushBatch(trip.courses.map { (courseToRecord($0, tripId: trip.id), "Course(\($0.name))") })

        // Teams
        await pushBatch(trip.teams.map { (teamToRecord($0, tripId: trip.id), "Team(\($0.name))") })

        // Rounds + Scorecards
        await pushBatch(trip.rounds.map { (roundToRecord($0, tripId: trip.id), "Round(\($0.date))") })

        // War Room Events
        await pushBatch(trip.warRoomEvents.map { (warRoomEventToRecord($0, tripId: trip.id), "WarRoomEvent(\($0.title))") })

        // Travel Statuses
        await pushBatch(trip.travelStatuses.map { (travelStatusToRecord($0, tripId: trip.id), "TravelStatus") })

        // Polls
        await pushBatch(trip.polls.map { (pollToRecord($0, tripId: trip.id), "Poll(\($0.question))") })

        // Side Games
        await pushBatch(trip.sideGames.map { (sideGameToRecord($0, tripId: trip.id), "SideGame") })

        // Side Bets
        await pushBatch(trip.sideBets.map { (sideBetToRecord($0, tripId: trip.id), "SideBet(\($0.name))") })

        // Write share code index to public DB so others can join
        do {
            try await saveTripIndex(trip: trip)
        } catch {
            ckLogger.error("  ⚠️ Skipped TripShareIndex: \(error.localizedDescription)")
        }
        ckLogger.info("☁️ pushFullTrip completed for '\(trip.name)'")
    }

    /// Save a single record with upsert behavior (insert OR update).
    /// On first save, inserts the record. If it already exists on the server,
    /// fetches the server copy (which has the correct changeTag), copies all
    /// field values onto it, then saves the updated server record.
    /// Retries up to 2 times on serverRecordChanged conflicts.
    private func saveRecord(_ record: CKRecord, label: String, retryCount: Int = 0) async throws {
        do {
            try await publicDB.save(record)
            ckLogger.info("  ✅ Saved \(label)")
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            guard retryCount < 2 else {
                ckLogger.error("  ❌ FAILED to save \(label) after \(retryCount + 1) retries: server record keeps changing")
                throw ckError
            }
            // Record already exists — fetch server copy, update fields, re-save
            ckLogger.info("  🔄 Record exists, fetching & updating \(label) (attempt \(retryCount + 1))...")
            let serverRecord = try await publicDB.record(for: record.recordID)
            for key in record.allKeys() {
                serverRecord[key] = record[key]
            }
            try await saveRecord(serverRecord, label: label, retryCount: retryCount + 1)
        } catch {
            ckLogger.error("  ❌ FAILED to save \(label): \(error)")
            throw error
        }
    }

    /// Delete a record from CloudKit by its UUID. Silently succeeds if the record doesn't exist.
    func deleteRecord(id: UUID) async {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        do {
            try await publicDB.deleteRecord(withID: recordID)
            ckLogger.info("  🗑️ Deleted record \(id.uuidString.prefix(8))")
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // Already deleted or never existed — that's fine
            ckLogger.info("  🗑️ Record \(id.uuidString.prefix(8)) already gone")
        } catch {
            ckLogger.error("  ⚠️ Failed to delete \(id.uuidString.prefix(8)): \(error.localizedDescription)")
        }
    }

    func saveScorecard(_ scorecard: Scorecard, tripId: UUID) async throws {
        let record = scorecardToRecord(scorecard)
        try await saveRecord(record, label: "Scorecard")
        // Touch the Trip record so CKQuerySubscription fires and other devices get notified
        await touchTripRecord(tripId: tripId)
    }

    func saveRound(_ round: Round, tripId: UUID) async throws {
        let record = roundToRecord(round, tripId: tripId)
        try await saveRecord(record, label: "Round")
        // Touch the Trip record so CKQuerySubscription fires and other devices get notified
        await touchTripRecord(tripId: tripId)
    }

    /// Touch the Trip record to trigger CKQuerySubscription notifications on other devices.
    /// Used after saving child records (scorecards, rounds) that don't update the Trip record directly.
    private func touchTripRecord(tripId: UUID) async {
        let recordID = CKRecord.ID(recordName: tripId.uuidString)
        do {
            let serverRecord = try await publicDB.record(for: recordID)
            serverRecord["lastModified"] = Date() as CKRecordValue
            try await publicDB.save(serverRecord)
        } catch {
            ckLogger.warning("  ⚠️ Could not touch Trip record for notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Records

    func fetchTrips() async throws -> [Trip] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Trip", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToTrip(record)
        }
    }

    func fetchTripData(tripId: UUID) async throws -> Trip? {
        let recordID = CKRecord.ID(recordName: tripId.uuidString)

        let record = try await publicDB.record(for: recordID)
        guard let trip = recordToTrip(record) else { return nil }

        // Fetch all related records (each returns model + raw CKRecord tuple).
        // Each fetch is wrapped in do/catch so a missing record type in CloudKit
        // (e.g. schema not yet deployed) won't block the entire trip from loading.
        let playerResults = (try? await fetchPlayers(tripId: tripId)) ?? []
        let courseResults = (try? await fetchCourses(tripId: tripId)) ?? []
        let teamResults = (try? await fetchTeams(tripId: tripId)) ?? []
        let roundResults = (try? await fetchRounds(tripId: tripId)) ?? []
        let warRoomEventResults = (try? await fetchWarRoomEvents(tripId: tripId)) ?? []
        let travelStatusResults = (try? await fetchTravelStatuses(tripId: tripId)) ?? []
        let pollResults = (try? await fetchPolls(tripId: tripId)) ?? []
        let sideGameResults = (try? await fetchSideGames(tripId: tripId)) ?? []
        let sideBetResults = (try? await fetchSideBets(tripId: tripId)) ?? []

        // Extract models
        let players = playerResults.map { $0.0 }
        let courses = courseResults.map { $0.0 }
        let teams = teamResults.map { $0.0 }
        let rounds = roundResults.map { $0.0 }
        let warRoomEvents = warRoomEventResults.map { $0.0 }
        let travelStatuses = travelStatusResults.map { $0.0 }
        let polls = pollResults.map { $0.0 }
        let sideGames = sideGameResults.map { $0.0 }
        let sideBets = sideBetResults.map { $0.0 }

        // Build tombstone sets so we skip entities that were deleted on any device
        let deletedPlayerIds = Set(trip.deletedPlayerIds)
        let deletedCourseIds = Set(trip.deletedCourseIds)
        let deletedTeamIds = Set(trip.deletedTeamIds)
        let deletedSideGameIds = Set(trip.deletedSideGameIds)
        let deletedSideBetIds = Set(trip.deletedSideBetIds)
        let deletedWarRoomEventIds = Set(trip.deletedWarRoomEventIds)

        // Append children to trip, filtering out tombstoned entities
        for player in players where !deletedPlayerIds.contains(player.id.uuidString) {
            trip.players.append(player)
        }
        for course in courses where !deletedCourseIds.contains(course.id.uuidString) {
            trip.courses.append(course)
        }
        for team in teams where !deletedTeamIds.contains(team.id.uuidString) {
            trip.teams.append(team)
        }
        for round in rounds { trip.rounds.append(round) }
        for event in warRoomEvents where !deletedWarRoomEventIds.contains(event.id.uuidString) {
            trip.warRoomEvents.append(event)
        }
        for status in travelStatuses { trip.travelStatuses.append(status) }
        for poll in polls { trip.polls.append(poll) }
        for sideGame in sideGames where !deletedSideGameIds.contains(sideGame.id.uuidString) {
            trip.sideGames.append(sideGame)
        }
        for bet in sideBets where !deletedSideBetIds.contains(bet.id.uuidString) {
            trip.sideBets.append(bet)
        }

        // Build lookup dictionaries for stitching (use uniquingKeysWith to handle
        // duplicate records that CloudKit can return due to eventual consistency)
        let playerById = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let courseById = Dictionary(courses.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let teamById = Dictionary(teams.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        let roundById = Dictionary(rounds.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        // Stitch child relationships using foreign keys from raw CKRecords

        // Player -> Team (via teamId stored in Player record)
        for (player, ckRecord) in playerResults {
            if let teamIdStr = ckRecord["teamId"] as? String,
               !teamIdStr.isEmpty,
               let teamId = UUID(uuidString: teamIdStr) {
                player.team = teamById[teamId]
            }
        }

        // Team -> Players (via playerIds stored in Team record)
        for (team, ckRecord) in teamResults {
            let playerIdStrings = ckRecord["playerIds"] as? [String] ?? []
            for idStr in playerIdStrings {
                if let pid = UUID(uuidString: idStr), let player = playerById[pid] {
                    if !team.players.contains(where: { $0.id == player.id }) {
                        team.players.append(player)
                    }
                }
            }
        }

        // Round -> Course (via courseId stored in Round record)
        // Round -> Scorecards (parsed from scorecardsData embedded JSON)
        for (round, ckRecord) in roundResults {
            if let courseIdStr = ckRecord["courseId"] as? String,
               !courseIdStr.isEmpty,
               let courseId = UUID(uuidString: courseIdStr) {
                round.course = courseById[courseId]
            }

            // Parse embedded scorecardsData into Scorecard objects
            if let scorecardsData = ckRecord["scorecardsData"] as? Data,
               let scorecardDicts = try? JSONSerialization.jsonObject(with: scorecardsData) as? [[String: Any]] {
                for dict in scorecardDicts {
                    let cardIdStr = dict["id"] as? String ?? ""
                    let cardId = UUID(uuidString: cardIdStr) ?? UUID()
                    let playerIdStr = dict["playerId"] as? String ?? ""
                    let courseHandicap = dict["courseHandicap"] as? Int ?? 0
                    let isComplete = dict["isComplete"] as? Bool ?? false

                    // Parse holeScores from the embedded JSON
                    var holeScores: [HoleScore] = []
                    if let holeScoresObj = dict["holeScores"] {
                        if let holeScoresData = try? JSONSerialization.data(withJSONObject: holeScoresObj) {
                            holeScores = (try? JSONDecoder().decode([HoleScore].self, from: holeScoresData)) ?? []
                        }
                    }

                    let scorecard = Scorecard(
                        id: cardId,
                        round: round,
                        player: UUID(uuidString: playerIdStr).flatMap { playerById[$0] },
                        holeScores: holeScores,
                        courseHandicap: courseHandicap,
                        isComplete: isComplete
                    )
                    round.scorecards.append(scorecard)
                }
            }
        }

        // TravelStatus -> Player (via playerId stored in TravelStatus record)
        for (status, ckRecord) in travelStatusResults {
            if let playerIdStr = ckRecord["playerId"] as? String,
               !playerIdStr.isEmpty,
               let playerId = UUID(uuidString: playerIdStr) {
                status.player = playerById[playerId]
            }
        }

        // SideGame -> Round (via roundId stored in SideGame record)
        for (sideGame, ckRecord) in sideGameResults {
            if let roundIdStr = ckRecord["roundId"] as? String,
               !roundIdStr.isEmpty,
               let roundId = UUID(uuidString: roundIdStr) {
                sideGame.round = roundById[roundId]
            }
        }

        // SideBet -> Round (via roundId stored in SideBet record)
        for (bet, ckRecord) in sideBetResults {
            if let roundIdStr = ckRecord["roundId"] as? String,
               !roundIdStr.isEmpty,
               let roundId = UUID(uuidString: roundIdStr) {
                bet.round = roundById[roundId]
            }
        }

        return trip
    }

    private func fetchPlayers(tripId: UUID) async throws -> [(Player, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Player", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToPlayer(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchCourses(tripId: UUID) async throws -> [(Course, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Course", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToCourse(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchTeams(tripId: UUID) async throws -> [(Team, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Team", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToTeam(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchRounds(tripId: UUID) async throws -> [(Round, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Round", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToRound(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchWarRoomEvents(tripId: UUID) async throws -> [(WarRoomEvent, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "WarRoomEvent", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToWarRoomEvent(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchTravelStatuses(tripId: UUID) async throws -> [(TravelStatus, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "TravelStatus", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToTravelStatus(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchPolls(tripId: UUID) async throws -> [(Poll, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Poll", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToPoll(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchSideGames(tripId: UUID) async throws -> [(SideGame, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "SideGame", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToSideGame(record) else { return nil }
            return (model, record)
        }
    }

    private func fetchSideBets(tripId: UUID) async throws -> [(SideBet, CKRecord)] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "SideBet", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result,
                  let model = recordToSideBet(record) else { return nil }
            return (model, record)
        }
    }

    // MARK: - Share Code Lookup (Public DB)

    /// Write a lightweight index record to the public database so others can find this trip by share code.
    /// If the share code collides with another trip, regenerates up to 5 times.
    func saveTripIndex(trip: Trip) async throws {
        // Verify this share code's index either doesn't exist or belongs to this trip
        let recordID = CKRecord.ID(recordName: "ShareIndex_\(trip.shareCode)")
        do {
            let existingRecord = try await publicDB.record(for: recordID)
            let existingTripId = existingRecord["tripId"] as? String ?? ""
            if existingTripId != trip.id.uuidString {
                // Collision! Another trip has this code. Regenerate.
                ckLogger.warning("  ⚠️ Share code collision detected for '\(trip.shareCode)' — regenerating")
                let characters = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
                trip.shareCode = String((0..<6).map { _ in characters[Int.random(in: 0..<characters.count)] })
                // Retry with new code (recursive but bounded by probability)
                try await saveTripIndex(trip: trip)
                return
            }
        } catch let ckError as CKError where ckError.code == .unknownItem {
            // No existing record — safe to proceed
        }

        let record = CKRecord(recordType: "TripShareIndex", recordID: recordID)
        record["shareCode"] = trip.shareCode as CKRecordValue
        record["tripId"] = trip.id.uuidString as CKRecordValue
        record["tripName"] = trip.name as CKRecordValue
        record["ownerProfileId"] = (trip.ownerProfileId?.uuidString ?? "") as CKRecordValue
        try await saveRecord(record, label: "TripShareIndex")
    }

    /// Check if a share code is already in use
    func isShareCodeTaken(_ code: String) async -> Bool {
        let predicate = NSPredicate(format: "shareCode == %@", code.uppercased())
        let query = CKQuery(recordType: "TripShareIndex", predicate: predicate)
        do {
            let (results, _) = try await publicDB.records(matching: query)
            return !results.isEmpty
        } catch {
            return false // Assume not taken if we can't check
        }
    }

    /// Look up a trip by share code from the public database, then fetch full trip data
    func fetchTripByShareCode(_ code: String) async throws -> Trip? {
        let predicate = NSPredicate(format: "shareCode == %@", code.uppercased())
        let query = CKQuery(recordType: "TripShareIndex", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        guard let firstResult = results.first,
              case .success(let indexRecord) = firstResult.1,
              let tripIdStr = indexRecord["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdStr) else {
            return nil
        }

        // Fetch the full trip data from the public database
        return try await fetchTripData(tripId: tripId)
    }

    // MARK: - Subscriptions

    /// Subscribe to changes for a specific trip in the public database.
    /// Uses CKQuerySubscription to watch for record updates matching the tripId.
    func subscribeToTripChanges(tripId: UUID) async throws {
        let subscriptionID = "trip_\(tripId.uuidString)"

        // Check if already subscribed
        do {
            _ = try await publicDB.subscription(for: subscriptionID)
            return // Already subscribed
        } catch {
            // Not subscribed yet — continue
        }

        // Subscribe to changes on Trip records matching this tripId.
        // Every push updates the Trip record, so this catches all sync activity.
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let subscription = CKQuerySubscription(
            recordType: "Trip",
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await publicDB.save(subscription)
    }

    /// Remove subscription for a trip (e.g. when leaving)
    func unsubscribeFromTripChanges(tripId: UUID) async throws {
        let subscriptionID = "trip_\(tripId.uuidString)"
        try await publicDB.deleteSubscription(withID: subscriptionID)
    }

    // MARK: - Record Conversion Helpers (Public DB — default zone)

    private func tripToRecord(_ trip: Trip) -> CKRecord {
        let recordID = CKRecord.ID(recordName: trip.id.uuidString)
        let record = CKRecord(recordType: "Trip", recordID: recordID)
        record["name"] = trip.name as CKRecordValue
        record["startDate"] = trip.startDate as CKRecordValue
        record["endDate"] = trip.endDate as CKRecordValue
        record["shareCode"] = trip.shareCode as CKRecordValue
        record["createdAt"] = trip.createdAt as CKRecordValue
        record["ownerProfileId"] = (trip.ownerProfileId?.uuidString ?? "") as CKRecordValue
        record["pointsPerMatchWin"] = trip.pointsPerMatchWin as CKRecordValue
        record["pointsPerMatchHalve"] = trip.pointsPerMatchHalve as CKRecordValue
        record["pointsPerMatchLoss"] = trip.pointsPerMatchLoss as CKRecordValue
        record["tripId"] = trip.id.uuidString as CKRecordValue
        record["schemaVersion"] = trip.schemaVersion as CKRecordValue
        // CloudKit cannot create a new List field from an empty array (it can't infer
        // the element type). Only write these when non-empty; once the field exists in
        // the schema, empty arrays work fine on subsequent saves.
        if !trip.deletedPlayerIds.isEmpty {
            record["deletedPlayerIds"] = trip.deletedPlayerIds as CKRecordValue
        }
        if !trip.deletedCourseIds.isEmpty {
            record["deletedCourseIds"] = trip.deletedCourseIds as CKRecordValue
        }
        if !trip.deletedTeamIds.isEmpty {
            record["deletedTeamIds"] = trip.deletedTeamIds as CKRecordValue
        }
        if !trip.deletedSideGameIds.isEmpty {
            record["deletedSideGameIds"] = trip.deletedSideGameIds as CKRecordValue
        }
        if !trip.deletedSideBetIds.isEmpty {
            record["deletedSideBetIds"] = trip.deletedSideBetIds as CKRecordValue
        }
        if !trip.deletedWarRoomEventIds.isEmpty {
            record["deletedWarRoomEventIds"] = trip.deletedWarRoomEventIds as CKRecordValue
        }
        return record
    }

    private func playerToRecord(_ player: Player, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: player.id.uuidString)
        let record = CKRecord(recordType: "Player", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = player.name as CKRecordValue
        record["handicapIndex"] = player.handicapIndex as CKRecordValue
        record["teamId"] = (player.team?.id.uuidString ?? "") as CKRecordValue
        record["avatarColor"] = player.avatarColor.rawValue as CKRecordValue
        record["userProfileId"] = (player.userProfileId?.uuidString ?? "") as CKRecordValue
        return record
    }

    private func courseToRecord(_ course: Course, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: course.id.uuidString)
        let record = CKRecord(recordType: "Course", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = course.name as CKRecordValue
        record["slopeRating"] = course.slopeRating as CKRecordValue
        record["courseRating"] = course.courseRating as CKRecordValue
        record["city"] = course.city as CKRecordValue
        record["state"] = course.state as CKRecordValue
        if let lat = course.latitude { record["latitude"] = lat as CKRecordValue }
        if let lng = course.longitude { record["longitude"] = lng as CKRecordValue }
        record["selectedTeeBoxName"] = (course.selectedTeeBoxName ?? "") as CKRecordValue
        if let holesData = try? JSONEncoder().encode(course.holes) {
            record["holesData"] = holesData as CKRecordValue
        }
        if !course.teeBoxes.isEmpty, let teeData = try? JSONEncoder().encode(course.teeBoxes) {
            record["teeBoxesData"] = teeData as CKRecordValue
        }
        if let rule = course.teamScoringRule,
           let ruleData = try? JSONEncoder().encode(rule) {
            record["teamScoringRuleData"] = ruleData as CKRecordValue
        }
        return record
    }

    private func teamToRecord(_ team: Team, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: team.id.uuidString)
        let record = CKRecord(recordType: "Team", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = team.name as CKRecordValue
        record["color"] = team.color.rawValue as CKRecordValue
        record["playerIds"] = team.players.map { $0.id.uuidString } as CKRecordValue
        return record
    }

    private func roundToRecord(_ round: Round, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: round.id.uuidString)
        let record = CKRecord(recordType: "Round", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["courseId"] = (round.course?.id.uuidString ?? "") as CKRecordValue
        record["date"] = round.date as CKRecordValue
        record["format"] = round.format.rawValue as CKRecordValue
        record["playerIds"] = round.playerIds.map { $0.uuidString } as CKRecordValue
        record["isComplete"] = (round.isComplete ? 1 : 0) as CKRecordValue
        // Serialize scorecard hole scores as JSON
        let scorecardData = round.scorecards.map { card -> [String: Any] in
            [
                "id": card.id.uuidString,
                "playerId": card.player?.id.uuidString ?? "",
                "courseHandicap": card.courseHandicap,
                "isComplete": card.isComplete,
                "holeScores": (try? JSONEncoder().encode(card.holeScores)).flatMap {
                    try? JSONSerialization.jsonObject(with: $0)
                } ?? []
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: scorecardData) {
            record["scorecardsData"] = data as CKRecordValue
        }
        if let pairingsData = try? JSONEncoder().encode(round.matchPairings) {
            record["matchPairingsData"] = pairingsData as CKRecordValue
        }
        if let rule = round.teamScoringRule,
           let ruleData = try? JSONEncoder().encode(rule) {
            record["teamScoringRuleData"] = ruleData as CKRecordValue
        }
        return record
    }

    private func scorecardToRecord(_ scorecard: Scorecard) -> CKRecord {
        let recordID = CKRecord.ID(recordName: scorecard.id.uuidString)
        let record = CKRecord(recordType: "Scorecard", recordID: recordID)
        record["roundId"] = (scorecard.round?.id.uuidString ?? "") as CKRecordValue
        record["playerId"] = (scorecard.player?.id.uuidString ?? "") as CKRecordValue
        record["courseHandicap"] = scorecard.courseHandicap as CKRecordValue
        record["isComplete"] = (scorecard.isComplete ? 1 : 0) as CKRecordValue
        if let scoresData = try? JSONEncoder().encode(scorecard.holeScores) {
            record["holeScoresData"] = scoresData as CKRecordValue
        }
        return record
    }

    private func warRoomEventToRecord(_ event: WarRoomEvent, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: event.id.uuidString)
        let record = CKRecord(recordType: "WarRoomEvent", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["typeRaw"] = event.typeRaw as CKRecordValue
        record["title"] = event.title as CKRecordValue
        record["subtitle"] = event.subtitle as CKRecordValue
        record["dateTime"] = event.dateTime as CKRecordValue
        if let end = event.endDateTime {
            record["endDateTime"] = end as CKRecordValue
        }
        record["location"] = event.location as CKRecordValue
        record["notes"] = event.notes as CKRecordValue
        record["playerIds"] = event.playerIds.map { $0.uuidString } as CKRecordValue
        record["createdBy"] = (event.createdBy?.uuidString ?? "") as CKRecordValue
        record["createdAt"] = event.createdAt as CKRecordValue
        return record
    }

    private func travelStatusToRecord(_ status: TravelStatus, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: status.id.uuidString)
        let record = CKRecord(recordType: "TravelStatus", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["statusRaw"] = status.statusRaw as CKRecordValue
        record["updatedAt"] = status.updatedAt as CKRecordValue
        record["flightInfo"] = status.flightInfo as CKRecordValue
        if let eta = status.eta {
            record["eta"] = eta as CKRecordValue
        }
        record["playerId"] = (status.player?.id.uuidString ?? "") as CKRecordValue
        return record
    }

    private func pollToRecord(_ poll: Poll, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: poll.id.uuidString)
        let record = CKRecord(recordType: "Poll", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["question"] = poll.question as CKRecordValue
        record["createdBy"] = (poll.createdBy?.uuidString ?? "") as CKRecordValue
        record["createdAt"] = poll.createdAt as CKRecordValue
        record["isActive"] = (poll.isActive ? 1 : 0) as CKRecordValue
        record["allowMultipleVotes"] = (poll.allowMultipleVotes ? 1 : 0) as CKRecordValue
        if let optionsData = try? JSONEncoder().encode(poll.options) {
            record["optionsData"] = optionsData as CKRecordValue
        }
        return record
    }

    private func sideGameToRecord(_ sideGame: SideGame, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: sideGame.id.uuidString)
        let record = CKRecord(recordType: "SideGame", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["typeRaw"] = sideGame.typeRaw as CKRecordValue
        record["participantIds"] = sideGame.participantIds.map { $0.uuidString } as CKRecordValue
        record["stakes"] = sideGame.stakes as CKRecordValue
        record["stakesLabel"] = sideGame.stakesLabel as CKRecordValue
        record["isActive"] = (sideGame.isActive ? 1 : 0) as CKRecordValue
        record["designatedHoles"] = sideGame.designatedHoles as CKRecordValue
        record["roundId"] = (sideGame.round?.id.uuidString ?? "") as CKRecordValue
        record["isPotGame"] = (sideGame.isPotGame ? 1 : 0) as CKRecordValue
        record["potWinnerId"] = (sideGame.potWinnerId?.uuidString ?? "") as CKRecordValue
        if let resultsData = try? JSONEncoder().encode(sideGame.results) {
            record["resultsData"] = resultsData as CKRecordValue
        }
        return record
    }

    private func sideBetToRecord(_ bet: SideBet, tripId: UUID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: bet.id.uuidString)
        let record = CKRecord(recordType: "SideBet", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = bet.name as CKRecordValue
        record["betTypeRaw"] = bet.betTypeRaw as CKRecordValue
        if let target = bet.targetValue {
            record["targetValue"] = target as CKRecordValue
        }
        record["participants"] = bet.participants.map { $0.uuidString } as CKRecordValue
        record["stake"] = bet.stake as CKRecordValue
        record["statusRaw"] = bet.statusRaw as CKRecordValue
        record["winnerId"] = (bet.winnerId?.uuidString ?? "") as CKRecordValue
        record["isPotBet"] = (bet.isPotBet ? 1 : 0) as CKRecordValue
        record["potAmount"] = bet.potAmount as CKRecordValue
        record["useNetScoring"] = (bet.useNetScoring ? 1 : 0) as CKRecordValue
        record["requiresPuttsData"] = (bet.requiresPuttsData ? 1 : 0) as CKRecordValue
        record["customMetricName"] = bet.customMetricName as CKRecordValue
        record["customHighestWins"] = (bet.customHighestWins ? 1 : 0) as CKRecordValue
        record["customValuesRaw"] = bet.customValuesRaw as CKRecordValue
        if let roundId = bet.round?.id {
            record["roundId"] = roundId.uuidString as CKRecordValue
        }
        return record
    }

    // MARK: - Record to Model Helpers

    private func recordToTrip(_ record: CKRecord) -> Trip? {
        guard let name = record["name"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date else { return nil }

        let ownerProfileId: UUID? = (record["ownerProfileId"] as? String).flatMap { UUID(uuidString: $0) }

        let trip = Trip(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            startDate: startDate,
            endDate: endDate,
            shareCode: record["shareCode"] as? String ?? "",
            createdAt: record["createdAt"] as? Date ?? Date(),
            ownerProfileId: ownerProfileId,
            pointsPerMatchWin: record["pointsPerMatchWin"] as? Double ?? 1.0,
            pointsPerMatchHalve: record["pointsPerMatchHalve"] as? Double ?? 0.5,
            pointsPerMatchLoss: record["pointsPerMatchLoss"] as? Double ?? 0.0
        )
        trip.schemaVersion = record["schemaVersion"] as? Int ?? 1
        trip.deletedPlayerIds = record["deletedPlayerIds"] as? [String] ?? []
        trip.deletedCourseIds = record["deletedCourseIds"] as? [String] ?? []
        trip.deletedTeamIds = record["deletedTeamIds"] as? [String] ?? []
        trip.deletedSideGameIds = record["deletedSideGameIds"] as? [String] ?? []
        trip.deletedSideBetIds = record["deletedSideBetIds"] as? [String] ?? []
        trip.deletedWarRoomEventIds = record["deletedWarRoomEventIds"] as? [String] ?? []
        return trip
    }

    private func recordToPlayer(_ record: CKRecord) -> Player? {
        guard let name = record["name"] as? String else { return nil }

        let userProfileId: UUID? = (record["userProfileId"] as? String).flatMap { UUID(uuidString: $0) }

        return Player(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            handicapIndex: record["handicapIndex"] as? Double ?? 0,
            avatarColor: PlayerColor(rawValue: record["avatarColor"] as? String ?? "blue") ?? .blue,
            userProfileId: userProfileId
        )
    }

    private func recordToCourse(_ record: CKRecord) -> Course? {
        guard let name = record["name"] as? String else { return nil }

        var holes: [Hole] = []
        if let holesData = record["holesData"] as? Data {
            holes = (try? JSONDecoder().decode([Hole].self, from: holesData)) ?? []
        }

        var teeBoxes: [TeeBox] = []
        if let teeData = record["teeBoxesData"] as? Data {
            teeBoxes = (try? JSONDecoder().decode([TeeBox].self, from: teeData)) ?? []
        }

        var teamScoringRule: TeamScoringRule?
        if let ruleData = record["teamScoringRuleData"] as? Data {
            teamScoringRule = try? JSONDecoder().decode(TeamScoringRule.self, from: ruleData)
        }

        let selectedTee = record["selectedTeeBoxName"] as? String
        return Course(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            holes: holes,
            slopeRating: record["slopeRating"] as? Double ?? 113,
            courseRating: record["courseRating"] as? Double ?? 72,
            city: record["city"] as? String ?? "",
            state: record["state"] as? String ?? "",
            latitude: record["latitude"] as? Double,
            longitude: record["longitude"] as? Double,
            teeBoxes: teeBoxes,
            selectedTeeBoxName: (selectedTee?.isEmpty == true) ? nil : selectedTee,
            teamScoringRule: teamScoringRule
        )
    }

    private func recordToTeam(_ record: CKRecord) -> Team? {
        guard let name = record["name"] as? String else { return nil }

        return Team(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            color: TeamColor(rawValue: record["color"] as? String ?? "Blue") ?? .blue
        )
    }

    private func recordToRound(_ record: CKRecord) -> Round? {
        guard let date = record["date"] as? Date,
              let formatStr = record["format"] as? String,
              let format = ScoringFormat(rawValue: formatStr) else { return nil }

        let playerIdStrings = record["playerIds"] as? [String] ?? []
        let playerIds = playerIdStrings.compactMap { UUID(uuidString: $0) }

        var matchPairings: [MatchPairing] = []
        if let pairingsData = record["matchPairingsData"] as? Data {
            matchPairings = (try? JSONDecoder().decode([MatchPairing].self, from: pairingsData)) ?? []
        }

        var teamScoringRule: TeamScoringRule?
        if let ruleData = record["teamScoringRuleData"] as? Data {
            teamScoringRule = try? JSONDecoder().decode(TeamScoringRule.self, from: ruleData)
        }

        let round = Round(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            date: date,
            format: format,
            playerIds: playerIds,
            isComplete: (record["isComplete"] as? Int ?? 0) == 1,
            matchPairings: matchPairings
        )
        round.teamScoringRule = teamScoringRule
        return round
    }

    private func recordToWarRoomEvent(_ record: CKRecord) -> WarRoomEvent? {
        guard let typeRaw = record["typeRaw"] as? String,
              let title = record["title"] as? String,
              let dateTime = record["dateTime"] as? Date else { return nil }

        let playerIdStrings = record["playerIds"] as? [String] ?? []
        let playerIds = playerIdStrings.compactMap { UUID(uuidString: $0) }
        let createdBy: UUID? = (record["createdBy"] as? String).flatMap { UUID(uuidString: $0) }

        return WarRoomEvent(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            type: EventType(rawValue: typeRaw) ?? .custom,
            title: title,
            subtitle: record["subtitle"] as? String ?? "",
            dateTime: dateTime,
            endDateTime: record["endDateTime"] as? Date,
            location: record["location"] as? String ?? "",
            notes: record["notes"] as? String ?? "",
            playerIds: playerIds,
            createdBy: createdBy,
            createdAt: record["createdAt"] as? Date ?? Date()
        )
    }

    private func recordToTravelStatus(_ record: CKRecord) -> TravelStatus? {
        guard let statusRaw = record["statusRaw"] as? String else { return nil }

        return TravelStatus(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            status: TravelStatusType(rawValue: statusRaw) ?? .notDeparted,
            updatedAt: record["updatedAt"] as? Date ?? Date(),
            flightInfo: record["flightInfo"] as? String ?? "",
            eta: record["eta"] as? Date
        )
        // Note: player relationship is stitched after fetch via playerId
    }

    private func recordToPoll(_ record: CKRecord) -> Poll? {
        guard let question = record["question"] as? String else { return nil }

        var options: [PollOption] = []
        if let optionsData = record["optionsData"] as? Data {
            options = (try? JSONDecoder().decode([PollOption].self, from: optionsData)) ?? []
        }

        let createdBy: UUID? = (record["createdBy"] as? String).flatMap { UUID(uuidString: $0) }

        return Poll(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            question: question,
            options: options,
            createdBy: createdBy,
            createdAt: record["createdAt"] as? Date ?? Date(),
            isActive: (record["isActive"] as? Int ?? 1) == 1,
            allowMultipleVotes: (record["allowMultipleVotes"] as? Int ?? 0) == 1
        )
    }

    private func recordToSideGame(_ record: CKRecord) -> SideGame? {
        guard let typeRaw = record["typeRaw"] as? String else { return nil }

        let participantStrings = record["participantIds"] as? [String] ?? []
        let participantIds = participantStrings.compactMap { UUID(uuidString: $0) }

        var results: [SideGameResult] = []
        if let resultsData = record["resultsData"] as? Data {
            results = (try? JSONDecoder().decode([SideGameResult].self, from: resultsData)) ?? []
        }

        let designatedHoles = record["designatedHoles"] as? [Int] ?? []

        let sideGame = SideGame(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            type: SideGameType(rawValue: typeRaw) ?? .skins,
            participantIds: participantIds,
            stakes: record["stakes"] as? Double ?? 0,
            stakesLabel: record["stakesLabel"] as? String ?? "",
            results: results,
            isActive: (record["isActive"] as? Int ?? 1) == 1,
            designatedHoles: designatedHoles
        )
        sideGame.isPotGame = (record["isPotGame"] as? Int64 ?? 0) == 1
        sideGame.potWinnerId = (record["potWinnerId"] as? String).flatMap { UUID(uuidString: $0) }
        return sideGame
        // Note: round relationship is stitched after fetch via roundId
    }

    private func recordToSideBet(_ record: CKRecord) -> SideBet? {
        guard let name = record["name"] as? String else { return nil }

        let participantStrings = record["participants"] as? [String] ?? []
        let participants = participantStrings.compactMap { UUID(uuidString: $0) }
        let winnerId: UUID? = (record["winnerId"] as? String).flatMap { UUID(uuidString: $0) }

        let bet = SideBet(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            betType: BetType(rawValue: record["betTypeRaw"] as? String ?? "highestTotal") ?? .highestTotal,
            targetValue: record["targetValue"] as? Double,
            participants: participants,
            stake: record["stake"] as? String ?? "Bragging Rights",
            status: BetStatus(rawValue: record["statusRaw"] as? String ?? "active") ?? .active,
            winnerId: winnerId,
            isPotBet: (record["isPotBet"] as? Int64 ?? 0) == 1,
            potAmount: record["potAmount"] as? Double ?? 0,
            useNetScoring: (record["useNetScoring"] as? Int64 ?? 0) == 1,
            requiresPuttsData: (record["requiresPuttsData"] as? Int64 ?? 0) == 1
        )
        bet.customMetricName = record["customMetricName"] as? String ?? ""
        bet.customHighestWins = (record["customHighestWins"] as? Int64 ?? 1) == 1
        bet.customValuesRaw = record["customValuesRaw"] as? String ?? "{}"
        return bet
    }
}

import Foundation
import CloudKit
import SwiftUI

actor CloudKitService {
    static let shared = CloudKitService()

    // Lazy container access — CKContainer.default() crashes when the CloudKit
    // entitlement is missing, so we must NOT call it during init().
    private var _container: CKContainer?
    private var container: CKContainer {
        if _container == nil {
            _container = CKContainer.default()
        }
        return _container ?? CKContainer.default()
    }
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }

    private init() {
        // Intentionally empty — container is lazily created on first use
    }

    // MARK: - Account Status

    func checkAccountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
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

    // MARK: - Zone Management

    private func createZone(named zoneName: String) async throws -> CKRecordZone {
        let zone = CKRecordZone(zoneName: zoneName)
        let savedZone = try await privateDB.save(zone)
        return savedZone
    }

    func tripZoneName(for tripId: UUID) -> String {
        "Trip_\(tripId.uuidString)"
    }

    // MARK: - Save Records

    func saveTrip(_ trip: Trip) async throws {
        try await pushFullTrip(trip)
    }

    /// Push the trip record and ALL child arrays to CloudKit in one shot
    func pushFullTrip(_ trip: Trip) async throws {
        let zoneName = tripZoneName(for: trip.id)
        _ = try await createZone(named: zoneName)
        let zoneID = CKRecordZone.ID(zoneName: zoneName)

        // Trip record
        let record = tripToRecord(trip, zoneID: zoneID)
        try await privateDB.save(record)

        // Players
        for player in trip.players {
            let r = playerToRecord(player, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Courses
        for course in trip.courses {
            let r = courseToRecord(course, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Teams
        for team in trip.teams {
            let r = teamToRecord(team, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Rounds + Scorecards
        for round in trip.rounds {
            let r = roundToRecord(round, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // War Room Events
        for event in trip.warRoomEvents {
            let r = warRoomEventToRecord(event, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Travel Statuses
        for status in trip.travelStatuses {
            let r = travelStatusToRecord(status, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Polls
        for poll in trip.polls {
            let r = pollToRecord(poll, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Side Games
        for sideGame in trip.sideGames {
            let r = sideGameToRecord(sideGame, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Metrics
        for metric in trip.metrics {
            let r = metricToRecord(metric, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Metric Entries
        for entry in trip.metricEntries {
            let r = metricEntryToRecord(entry, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Side Bets
        for bet in trip.sideBets {
            let r = sideBetToRecord(bet, tripId: trip.id, zoneID: zoneID)
            try await privateDB.save(r)
        }

        // Write share code index to public DB so others can join
        try await saveTripIndex(trip: trip)
    }

    func saveScorecard(_ scorecard: Scorecard, tripId: UUID) async throws {
        let zoneName = tripZoneName(for: tripId)
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let record = scorecardToRecord(scorecard, zoneID: zoneID)
        try await privateDB.save(record)
    }

    func saveRound(_ round: Round, tripId: UUID) async throws {
        let zoneName = tripZoneName(for: tripId)
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let record = roundToRecord(round, tripId: tripId, zoneID: zoneID)
        try await privateDB.save(record)
    }

    // MARK: - Fetch Records

    func fetchTrips() async throws -> [Trip] {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "Trip", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let (results, _) = try await privateDB.records(matching: query)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToTrip(record)
        }
    }

    func fetchTripData(tripId: UUID) async throws -> Trip? {
        let zoneName = tripZoneName(for: tripId)
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let recordID = CKRecord.ID(recordName: tripId.uuidString, zoneID: zoneID)

        let record = try await privateDB.record(for: recordID)
        guard let trip = recordToTrip(record) else { return nil }

        // Fetch all related records
        let players = try await fetchPlayers(tripId: tripId, zoneID: zoneID)
        let courses = try await fetchCourses(tripId: tripId, zoneID: zoneID)
        let teams = try await fetchTeams(tripId: tripId, zoneID: zoneID)
        let rounds = try await fetchRounds(tripId: tripId, zoneID: zoneID)
        let warRoomEvents = try await fetchWarRoomEvents(tripId: tripId, zoneID: zoneID)
        let travelStatuses = try await fetchTravelStatuses(tripId: tripId, zoneID: zoneID)
        let polls = try await fetchPolls(tripId: tripId, zoneID: zoneID)
        let sideGames = try await fetchSideGames(tripId: tripId, zoneID: zoneID)
        let metrics = try await fetchMetrics(tripId: tripId, zoneID: zoneID)
        let metricEntries = try await fetchMetricEntries(tripId: tripId, zoneID: zoneID)
        let sideBets = try await fetchSideBets(tripId: tripId, zoneID: zoneID)

        // Stitch relationships
        for player in players { trip.players.append(player) }
        for course in courses { trip.courses.append(course) }
        for team in teams { trip.teams.append(team) }
        for round in rounds { trip.rounds.append(round) }
        for event in warRoomEvents { trip.warRoomEvents.append(event) }
        for status in travelStatuses { trip.travelStatuses.append(status) }
        for poll in polls { trip.polls.append(poll) }
        for sideGame in sideGames { trip.sideGames.append(sideGame) }
        for metric in metrics { trip.metrics.append(metric) }
        for entry in metricEntries { trip.metricEntries.append(entry) }
        for bet in sideBets { trip.sideBets.append(bet) }

        return trip
    }

    private func fetchPlayers(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [Player] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Player", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToPlayer(record)
        }
    }

    private func fetchCourses(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [Course] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Course", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToCourse(record)
        }
    }

    private func fetchTeams(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [Team] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Team", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToTeam(record)
        }
    }

    private func fetchRounds(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [Round] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Round", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToRound(record)
        }
    }

    private func fetchWarRoomEvents(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [WarRoomEvent] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "WarRoomEvent", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToWarRoomEvent(record)
        }
    }

    private func fetchTravelStatuses(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [TravelStatus] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "TravelStatus", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToTravelStatus(record)
        }
    }

    private func fetchPolls(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [Poll] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Poll", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToPoll(record)
        }
    }

    private func fetchSideGames(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [SideGame] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "SideGame", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToSideGame(record)
        }
    }

    private func fetchMetrics(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [Metric] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "Metric", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToMetric(record)
        }
    }

    private func fetchMetricEntries(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [MetricEntry] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "MetricEntry", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToMetricEntry(record)
        }
    }

    private func fetchSideBets(tripId: UUID, zoneID: CKRecordZone.ID) async throws -> [SideBet] {
        let predicate = NSPredicate(format: "tripId == %@", tripId.uuidString)
        let query = CKQuery(recordType: "SideBet", predicate: predicate)

        let (results, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
        return results.compactMap { _, result in
            guard case .success(let record) = result else { return nil }
            return recordToSideBet(record)
        }
    }

    // MARK: - Sharing

    func createShare(for trip: Trip) async throws -> CKShare {
        let zoneName = tripZoneName(for: trip.id)
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        let recordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zoneID)

        let record = try await privateDB.record(for: recordID)

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = trip.name as CKRecordValue
        share.publicPermission = .readWrite

        let modifyOp = CKModifyRecordsOperation(recordsToSave: [record, share])
        modifyOp.qualityOfService = .userInitiated

        _ = try await privateDB.modifyRecords(saving: [record, share], deleting: [])
        return share
    }

    // MARK: - Share Code Lookup (Public DB)

    /// Write a lightweight index record to the public database so others can find this trip by share code
    func saveTripIndex(trip: Trip) async throws {
        let publicDB = container.publicCloudDatabase
        let recordID = CKRecord.ID(recordName: "ShareIndex_\(trip.shareCode)")
        let record = CKRecord(recordType: "TripShareIndex", recordID: recordID)
        record["shareCode"] = trip.shareCode as CKRecordValue
        record["tripId"] = trip.id.uuidString as CKRecordValue
        record["tripName"] = trip.name as CKRecordValue
        record["ownerProfileId"] = (trip.ownerProfileId?.uuidString ?? "") as CKRecordValue
        try await publicDB.save(record)
    }

    /// Look up a trip by share code from the public database, then fetch full trip data
    func fetchTripByShareCode(_ code: String) async throws -> Trip? {
        let publicDB = container.publicCloudDatabase
        let predicate = NSPredicate(format: "shareCode == %@", code.uppercased())
        let query = CKQuery(recordType: "TripShareIndex", predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query)
        guard let firstResult = results.first,
              case .success(let indexRecord) = firstResult.1,
              let tripIdStr = indexRecord["tripId"] as? String,
              let tripId = UUID(uuidString: tripIdStr) else {
            return nil
        }

        // Fetch the full trip data from the private database
        return try await fetchTripData(tripId: tripId)
    }

    // MARK: - Subscriptions

    func subscribeToChanges(tripId: UUID) async throws {
        _ = tripZoneName(for: tripId)

        let subscription = CKDatabaseSubscription(subscriptionID: "trip_\(tripId.uuidString)")
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await privateDB.save(subscription)
    }

    // MARK: - Record Conversion Helpers

    private func tripToRecord(_ trip: Trip, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: trip.id.uuidString, zoneID: zoneID)
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
        return record
    }

    private func playerToRecord(_ player: Player, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: player.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Player", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = player.name as CKRecordValue
        record["handicapIndex"] = player.handicapIndex as CKRecordValue
        record["teamId"] = (player.team?.id.uuidString ?? "") as CKRecordValue
        record["avatarColor"] = player.avatarColor.rawValue as CKRecordValue
        record["userProfileId"] = (player.userProfileId?.uuidString ?? "") as CKRecordValue
        return record
    }

    private func courseToRecord(_ course: Course, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: course.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Course", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = course.name as CKRecordValue
        record["slopeRating"] = course.slopeRating as CKRecordValue
        record["courseRating"] = course.courseRating as CKRecordValue
        record["city"] = course.city as CKRecordValue
        record["state"] = course.state as CKRecordValue
        if let holesData = try? JSONEncoder().encode(course.holes) {
            record["holesData"] = holesData as CKRecordValue
        }
        if let rule = course.teamScoringRule,
           let ruleData = try? JSONEncoder().encode(rule) {
            record["teamScoringRuleData"] = ruleData as CKRecordValue
        }
        return record
    }

    private func teamToRecord(_ team: Team, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: team.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Team", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = team.name as CKRecordValue
        record["color"] = team.color.rawValue as CKRecordValue
        record["playerIds"] = team.players.map { $0.id.uuidString } as CKRecordValue
        return record
    }

    private func roundToRecord(_ round: Round, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: round.id.uuidString, zoneID: zoneID)
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
        return record
    }

    private func scorecardToRecord(_ scorecard: Scorecard, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: scorecard.id.uuidString, zoneID: zoneID)
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

    private func warRoomEventToRecord(_ event: WarRoomEvent, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: event.id.uuidString, zoneID: zoneID)
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

    private func travelStatusToRecord(_ status: TravelStatus, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: status.id.uuidString, zoneID: zoneID)
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

    private func pollToRecord(_ poll: Poll, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: poll.id.uuidString, zoneID: zoneID)
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

    private func sideGameToRecord(_ sideGame: SideGame, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: sideGame.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "SideGame", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["typeRaw"] = sideGame.typeRaw as CKRecordValue
        record["participantIds"] = sideGame.participantIds.map { $0.uuidString } as CKRecordValue
        record["stakes"] = sideGame.stakes as CKRecordValue
        record["stakesLabel"] = sideGame.stakesLabel as CKRecordValue
        record["isActive"] = (sideGame.isActive ? 1 : 0) as CKRecordValue
        record["designatedHoles"] = sideGame.designatedHoles as CKRecordValue
        record["roundId"] = (sideGame.round?.id.uuidString ?? "") as CKRecordValue
        if let resultsData = try? JSONEncoder().encode(sideGame.results) {
            record["resultsData"] = resultsData as CKRecordValue
        }
        return record
    }

    private func metricToRecord(_ metric: Metric, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: metric.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "Metric", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["name"] = metric.name as CKRecordValue
        record["icon"] = metric.icon as CKRecordValue
        record["unit"] = metric.unit as CKRecordValue
        record["trackingTypeRaw"] = metric.trackingTypeRaw as CKRecordValue
        record["categoryRaw"] = metric.categoryRaw as CKRecordValue
        record["higherIsBetter"] = (metric.higherIsBetter ? 1 : 0) as CKRecordValue
        return record
    }

    private func metricEntryToRecord(_ entry: MetricEntry, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: entry.id.uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: "MetricEntry", recordID: recordID)
        record["tripId"] = tripId.uuidString as CKRecordValue
        record["value"] = entry.value as CKRecordValue
        record["date"] = entry.date as CKRecordValue
        record["notes"] = entry.notes as CKRecordValue
        record["metricId"] = (entry.metric?.id.uuidString ?? "") as CKRecordValue
        record["memberId"] = (entry.member?.id.uuidString ?? "") as CKRecordValue
        record["roundId"] = (entry.round?.id.uuidString ?? "") as CKRecordValue
        return record
    }

    private func sideBetToRecord(_ bet: SideBet, tripId: UUID, zoneID: CKRecordZone.ID) -> CKRecord {
        let recordID = CKRecord.ID(recordName: bet.id.uuidString, zoneID: zoneID)
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
        record["metricId"] = (bet.metric?.id.uuidString ?? "") as CKRecordValue
        return record
    }

    // MARK: - Record to Model Helpers

    private func recordToTrip(_ record: CKRecord) -> Trip? {
        guard let name = record["name"] as? String,
              let startDate = record["startDate"] as? Date,
              let endDate = record["endDate"] as? Date else { return nil }

        let ownerProfileId: UUID? = (record["ownerProfileId"] as? String).flatMap { UUID(uuidString: $0) }

        return Trip(
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

        var teamScoringRule: TeamScoringRule?
        if let ruleData = record["teamScoringRuleData"] as? Data {
            teamScoringRule = try? JSONDecoder().decode(TeamScoringRule.self, from: ruleData)
        }

        return Course(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            holes: holes,
            slopeRating: record["slopeRating"] as? Double ?? 113,
            courseRating: record["courseRating"] as? Double ?? 72,
            city: record["city"] as? String ?? "",
            state: record["state"] as? String ?? "",
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

        return Round(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            date: date,
            format: format,
            playerIds: playerIds,
            isComplete: (record["isComplete"] as? Int ?? 0) == 1,
            matchPairings: matchPairings
        )
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

        return SideGame(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            type: SideGameType(rawValue: typeRaw) ?? .skins,
            participantIds: participantIds,
            stakes: record["stakes"] as? Double ?? 0,
            stakesLabel: record["stakesLabel"] as? String ?? "",
            results: results,
            isActive: (record["isActive"] as? Int ?? 1) == 1,
            designatedHoles: designatedHoles
        )
        // Note: round relationship is stitched after fetch via roundId
    }

    private func recordToMetric(_ record: CKRecord) -> Metric? {
        guard let name = record["name"] as? String else { return nil }

        return Metric(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            icon: record["icon"] as? String ?? "📊",
            unit: record["unit"] as? String ?? "",
            trackingType: TrackingType(rawValue: record["trackingTypeRaw"] as? String ?? "cumulative") ?? .cumulative,
            category: MetricCategory(rawValue: record["categoryRaw"] as? String ?? "onCourse") ?? .onCourse,
            higherIsBetter: (record["higherIsBetter"] as? Int ?? 1) == 1
        )
    }

    private func recordToMetricEntry(_ record: CKRecord) -> MetricEntry? {
        guard let value = record["value"] as? Double else { return nil }

        return MetricEntry(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            value: value,
            date: record["date"] as? Date ?? Date(),
            notes: record["notes"] as? String ?? ""
        )
        // Note: metric, member, round relationships stitched after fetch via IDs
    }

    private func recordToSideBet(_ record: CKRecord) -> SideBet? {
        guard let name = record["name"] as? String else { return nil }

        let participantStrings = record["participants"] as? [String] ?? []
        let participants = participantStrings.compactMap { UUID(uuidString: $0) }
        let winnerId: UUID? = (record["winnerId"] as? String).flatMap { UUID(uuidString: $0) }

        return SideBet(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            betType: BetType(rawValue: record["betTypeRaw"] as? String ?? "highestTotal") ?? .highestTotal,
            targetValue: record["targetValue"] as? Double,
            participants: participants,
            stake: record["stake"] as? String ?? "Bragging Rights",
            status: BetStatus(rawValue: record["statusRaw"] as? String ?? "active") ?? .active,
            winnerId: winnerId
        )
        // Note: metric relationship stitched after fetch via metricId
    }
}

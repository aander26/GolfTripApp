import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.alex-apps.golftrip", category: "Migration")

/// Migrates trip data from UserDefaults JSON → SwiftData on first launch.
///
/// The old persistence layer saved the entire `[Trip]` array as JSON under
/// `UserDefaults.standard["savedTrips"]`. This migrator decodes that JSON
/// using `LegacyModels`, creates `@Model` instances, inserts them into the
/// ModelContext, and flags migration as complete.
enum UserDefaultsMigrator {

    private static let migrationKey = "swiftdata_migration_complete"
    private static let legacyTripsKey = "savedTrips"
    private static let migrationAttemptCountKey = "swiftdata_migration_attempts"
    private static let maxMigrationAttempts = 3

    /// Returns `true` if the migration has already been performed.
    static var isMigrated: Bool {
        UserDefaults.standard.bool(forKey: migrationKey)
    }

    /// Run the one-time migration. Safe to call on every launch — returns immediately
    /// if already migrated or if there is no legacy data.
    @MainActor
    static func migrateIfNeeded(context: ModelContext) {
        guard !isMigrated else { return }

        guard let data = UserDefaults.standard.data(forKey: legacyTripsKey),
              let legacyTrips = try? JSONDecoder().decode([LegacyModels.Trip].self, from: data),
              !legacyTrips.isEmpty else {
            // No legacy data — mark complete and return
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        for legacy in legacyTrips {
            let trip = convertTrip(legacy)
            context.insert(trip)
        }

        do {
            try context.save()
            // Only mark complete and clean up legacy data after successful save
            UserDefaults.standard.set(true, forKey: migrationKey)
            UserDefaults.standard.removeObject(forKey: legacyTripsKey)
            UserDefaults.standard.removeObject(forKey: migrationAttemptCountKey)
            logger.info("Migration completed successfully for \(legacyTrips.count) trips")
        } catch {
            // Save failed — do NOT mark migration complete or delete legacy data.
            // Track attempt count so we can surface an error after repeated failures.
            let attempts = UserDefaults.standard.integer(forKey: migrationAttemptCountKey) + 1
            UserDefaults.standard.set(attempts, forKey: migrationAttemptCountKey)

            if attempts >= maxMigrationAttempts {
                logger.error("Migration failed \(attempts) times — giving up. Error: \(error.localizedDescription)")
                // Mark as migrated to stop retrying, but post a notification so AppState can show an error
                UserDefaults.standard.set(true, forKey: migrationKey)
                NotificationCenter.default.post(
                    name: Notification.Name("MigrationFailed"),
                    object: nil,
                    userInfo: ["error": error.localizedDescription]
                )
            } else {
                logger.error("Migration save failed (attempt \(attempts)/\(maxMigrationAttempts)): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Conversion Helpers

    /// Current schema version for newly migrated trips.
    /// Must match the latest Trip.schemaVersion default.
    private static let currentSchemaVersion = 2

    private static func convertTrip(_ legacy: LegacyModels.Trip) -> Trip {
        let trip = Trip(
            id: legacy.id,
            name: legacy.name,
            startDate: legacy.startDate,
            endDate: legacy.endDate,
            shareCode: legacy.shareCode,
            createdAt: legacy.createdAt
        )
        // Explicitly set schema version so migrated trips are recognized as up-to-date.
        // Without this, future schema checks might re-migrate or mishandle these trips.
        trip.schemaVersion = currentSchemaVersion

        // Players
        let players = legacy.players.map { convertPlayer($0) }
        trip.players = players

        // Teams
        let teams = legacy.teams.map { convertTeam($0) }
        trip.teams = teams

        // Stitch player↔team relationships
        for legacyPlayer in legacy.players {
            if let teamId = legacyPlayer.teamId,
               let player = players.first(where: { $0.id == legacyPlayer.id }),
               let team = teams.first(where: { $0.id == teamId }) {
                player.team = team
            }
        }

        // Courses
        let courses = legacy.courses.map { convertCourse($0) }
        trip.courses = courses

        // Rounds + Scorecards
        let rounds = legacy.rounds.map { legacyRound -> Round in
            let round = convertRound(legacyRound)
            // Link course
            round.course = courses.first(where: { $0.id == legacyRound.courseId })
            // Convert scorecards
            round.scorecards = legacyRound.scorecards.map { legacyCard in
                let card = convertScorecard(legacyCard)
                card.round = round
                card.player = players.first(where: { $0.id == legacyCard.playerId })
                return card
            }
            return round
        }
        trip.rounds = rounds

        // Side Games
        trip.sideGames = legacy.sideGames.map { legacySG in
            let sg = convertSideGame(legacySG)
            sg.round = rounds.first(where: { $0.id == legacySG.roundId })
            return sg
        }

        // War Room Events
        trip.warRoomEvents = legacy.warRoomEvents.map { convertWarRoomEvent($0) }

        // Travel Statuses
        trip.travelStatuses = legacy.travelStatuses.map { legacyTS in
            let ts = convertTravelStatus(legacyTS)
            ts.player = players.first(where: { $0.id == legacyTS.playerId })
            return ts
        }

        // Polls
        trip.polls = legacy.polls.map { convertPoll($0) }

        // Side Bets
        trip.sideBets = legacy.sideBets.map { convertSideBet($0) }

        return trip
    }

    private static func convertPlayer(_ l: LegacyModels.Player) -> Player {
        Player(
            id: l.id,
            name: l.name,
            handicapIndex: l.handicapIndex,
            avatarColor: PlayerColor(rawValue: l.avatarColor) ?? .blue
        )
    }

    private static func convertTeam(_ l: LegacyModels.Team) -> Team {
        Team(
            id: l.id,
            name: l.name,
            color: TeamColor(rawValue: l.color) ?? .blue
        )
    }

    private static func convertCourse(_ l: LegacyModels.Course) -> Course {
        let holes = l.holes.map { h in
            Hole(number: h.number, par: h.par, yardage: h.yardage, handicapRating: h.handicapRating)
        }
        return Course(
            id: l.id,
            name: l.name,
            holes: holes,
            slopeRating: l.slopeRating,
            courseRating: l.courseRating,
            city: l.city,
            state: l.state,
            latitude: l.latitude,
            longitude: l.longitude
        )
    }

    private static func convertRound(_ l: LegacyModels.Round) -> Round {
        Round(
            id: l.id,
            date: l.date,
            format: ScoringFormat(rawValue: l.format) ?? .strokePlay,
            playerIds: l.playerIds,
            isComplete: l.isComplete
        )
    }

    private static func convertScorecard(_ l: LegacyModels.Scorecard) -> Scorecard {
        let scores = l.holeScores.map { h in
            HoleScore(
                holeNumber: h.holeNumber,
                strokes: h.strokes ?? 0,
                strokesReceived: h.handicapStrokes,
                putts: h.putts ?? 0
            )
        }
        return Scorecard(
            id: l.id,
            holeScores: scores,
            courseHandicap: l.courseHandicap,
            isComplete: l.isComplete
        )
    }

    private static func convertSideGame(_ l: LegacyModels.SideGame) -> SideGame {
        let results = l.results.map { r in
            SideGameResult(
                holeNumber: r.holeNumber,
                winnerId: r.playerId,
                amount: r.amount,
                description: r.description
            )
        }
        return SideGame(
            id: l.id,
            type: SideGameType(rawValue: l.type) ?? .skins,
            participantIds: l.participantIds,
            stakes: l.stakes,
            results: results,
            isActive: !l.isComplete
        )
    }

    private static func convertWarRoomEvent(_ l: LegacyModels.WarRoomEvent) -> WarRoomEvent {
        WarRoomEvent(
            id: l.id,
            type: EventType(rawValue: l.type) ?? .custom,
            title: l.title,
            subtitle: l.subtitle,
            dateTime: l.dateTime,
            endDateTime: l.endDateTime,
            location: l.location,
            notes: l.notes,
            playerIds: l.playerIds
        )
    }

    private static func convertTravelStatus(_ l: LegacyModels.TravelStatus) -> TravelStatus {
        TravelStatus(
            id: l.id,
            status: TravelStatusType(rawValue: l.status) ?? .notDeparted,
            updatedAt: l.updatedAt,
            flightInfo: l.flightInfo ?? ""
        )
    }

    private static func convertPoll(_ l: LegacyModels.Poll) -> Poll {
        let options = l.options.map { o in
            PollOption(id: o.id, text: o.text, voterIds: o.voterIds)
        }
        return Poll(
            id: l.id,
            question: l.question,
            options: options,
            isActive: l.isActive
        )
    }

    private static func convertSideBet(_ l: LegacyModels.SideBet) -> SideBet {
        SideBet(
            id: l.id,
            name: l.name,
            betType: BetType(rawValue: l.betType) ?? .highestTotal,
            targetValue: l.target,
            participants: l.participants,
            stake: l.stake,
            status: BetStatus(rawValue: l.status) ?? .active,
            winnerId: l.winnerId
        )
    }
}

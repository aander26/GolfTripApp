import Foundation

// MARK: - Legacy Codable models for UserDefaults → SwiftData migration
// These mirror the old struct-based Trip model graph so we can decode
// any JSON that was persisted in UserDefaults before the SwiftData migration.

enum LegacyModels {

    struct Trip: Codable {
        var id: UUID
        var name: String
        var startDate: Date
        var endDate: Date
        var shareCode: String
        var createdAt: Date
        var players: [Player]
        var teams: [Team]
        var courses: [Course]
        var rounds: [Round]
        var sideGames: [SideGame]
        var warRoomEvents: [WarRoomEvent]
        var travelStatuses: [TravelStatus]
        var polls: [Poll]
        var metrics: [Metric]
        var metricEntries: [MetricEntry]
        var sideBets: [SideBet]
    }

    struct Player: Codable {
        var id: UUID
        var name: String
        var handicapIndex: Double
        var teamId: UUID?
        var avatarColor: String
    }

    struct Team: Codable {
        var id: UUID
        var name: String
        var color: String
        var playerIds: [UUID]
    }

    struct Course: Codable {
        var id: UUID
        var name: String
        var holes: [Hole]
        var slopeRating: Double
        var courseRating: Double
        var city: String
        var state: String
        var latitude: Double?
        var longitude: Double?
    }

    struct Round: Codable {
        var id: UUID
        var courseId: UUID
        var date: Date
        var format: String
        var playerIds: [UUID]
        var scorecards: [Scorecard]
        var isComplete: Bool
    }

    struct Scorecard: Codable {
        var id: UUID
        var roundId: UUID
        var playerId: UUID
        var courseHandicap: Int
        var holeScores: [HoleScore]
        var isComplete: Bool
    }

    struct HoleScore: Codable {
        var holeNumber: Int
        var strokes: Int?
        var putts: Int?
        var fairwayHit: Bool?
        var greenInRegulation: Bool?
        var handicapStrokes: Int
    }

    struct Hole: Codable {
        var number: Int
        var par: Int
        var yardage: Int
        var handicapRating: Int
    }

    struct SideGame: Codable {
        var id: UUID
        var type: String
        var roundId: UUID
        var participantIds: [UUID]
        var stakes: Double
        var results: [SideGameResult]
        var isComplete: Bool
    }

    struct SideGameResult: Codable {
        var playerId: UUID
        var holeNumber: Int
        var amount: Double
        var description: String
    }

    struct WarRoomEvent: Codable {
        var id: UUID
        var type: String
        var title: String
        var subtitle: String
        var dateTime: Date
        var endDateTime: Date?
        var location: String
        var notes: String
        var playerIds: [UUID]
    }

    struct TravelStatus: Codable {
        var id: UUID
        var playerId: UUID
        var status: String
        var updatedAt: Date
        var flightInfo: String?
    }

    struct Poll: Codable {
        var id: UUID
        var question: String
        var options: [PollOption]
        var isActive: Bool
    }

    struct PollOption: Codable {
        var id: UUID
        var text: String
        var voterIds: [UUID]
    }

    // NOTE: Metric and MetricEntry structs are intentionally preserved here for legacy
    // UserDefaults JSON decoding. The metrics system was removed from the app, but these
    // definitions are needed so old data can still be decoded during migration without crashing.
    struct Metric: Codable {
        var id: UUID
        var name: String
        var icon: String
        var unit: String
        var trackingType: String
        var category: String
        var higherIsBetter: Bool
    }

    struct MetricEntry: Codable {
        var id: UUID
        var metricId: UUID
        var memberId: UUID
        var value: Double
        var roundId: UUID?
        var date: Date
        var notes: String
    }

    struct SideBet: Codable {
        var id: UUID
        var name: String
        var metricId: UUID  // Legacy field — metrics system removed, kept for JSON decoding
        var betType: String
        var participants: [UUID]
        var stake: String
        var target: Double?
        var winnerId: UUID?
        var status: String
    }
}

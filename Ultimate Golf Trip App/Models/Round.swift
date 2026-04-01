import Foundation
import SwiftData

@Model
final class Round {
    var id: UUID = UUID()
    var date: Date = Date()
    var formatRaw: String = "strokePlay"
    var playerIds: [UUID] = []
    var isComplete: Bool = false

    /// Timestamp of last modification, used for merge conflict resolution.
    var updatedAt: Date = Date()

    /// Optional match pairings for team match play. When empty, engine auto-pairs by team roster order.
    var matchPairings: [MatchPairing] = []

    // Relationships
    var course: Course?
    @Relationship(deleteRule: .cascade, inverse: \Scorecard.round)
    var scorecards: [Scorecard]
    @Relationship(inverse: \Trip.rounds)
    var trip: Trip?

    init(
        id: UUID = UUID(),
        course: Course? = nil,
        date: Date = Date(),
        format: ScoringFormat = .strokePlay,
        playerIds: [UUID] = [],
        scorecards: [Scorecard] = [],
        isComplete: Bool = false,
        matchPairings: [MatchPairing] = []
    ) {
        self.id = id
        self.course = course
        self.date = date
        self.formatRaw = format.rawValue
        self.playerIds = playerIds
        self.scorecards = scorecards
        self.isComplete = isComplete
        self.matchPairings = matchPairings
    }

    // MARK: - Computed Properties

    var format: ScoringFormat {
        get { ScoringFormat(rawValue: formatRaw) ?? .strokePlay }
        set { formatRaw = newValue.rawValue }
    }

    /// Backward-compat
    var courseId: UUID? { course?.id }

    var formattedDate: String {
        CachedFormatters.mediumDate.string(from: date)
    }

    func scorecard(forPlayer playerId: UUID) -> Scorecard? {
        scorecards.first { $0.player?.id == playerId }
    }

    var completedScorecards: [Scorecard] {
        scorecards.filter { $0.isComplete }
    }

    var inProgressScorecards: [Scorecard] {
        scorecards.filter { !$0.isComplete && $0.holesCompleted > 0 }
    }

    func updateScorecard(_ scorecard: Scorecard) {
        // With reference types, the scorecard is already mutated in-place
        // This method is kept for API compatibility
    }
}

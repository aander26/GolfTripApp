import Foundation
import SwiftData

@Model
final class Round {
    var id: UUID
    var date: Date
    var formatRaw: String
    var playerIds: [UUID]
    var isComplete: Bool

    /// Optional match pairings for team match play. When empty, engine auto-pairs by team roster order.
    var matchPairings: [MatchPairing]

    // Relationships
    var course: Course?
    @Relationship(deleteRule: .cascade)
    var scorecards: [Scorecard]
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
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
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

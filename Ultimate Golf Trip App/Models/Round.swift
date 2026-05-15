import Foundation
import SwiftData

@Model
final class Round {
    var id: UUID = UUID()
    var date: Date = Date()
    var formatRaw: String = "strokePlay"
    var playerIds: [UUID] = []
    var isComplete: Bool = false

    /// Whether putts are tracked for this round. When false, the putts UI is hidden in scoring views
    /// and the swipe-to-score flow skips the putts step. Challenges that require putts data
    /// override this and force putts entry regardless.
    var trackPutts: Bool = true

    /// Timestamp of last modification, used for merge conflict resolution.
    var updatedAt: Date = Date()

    /// Team scoring rule for this round (set at creation time).
    /// Stored per-round so reusing a course with a different format doesn't overwrite history.
    var teamScoringRule: TeamScoringRule?

    /// Optional match pairings for team match play. When empty, engine auto-pairs by team roster order.
    var matchPairings: [MatchPairing] = []

    /// Optional playing groups (foursomes). When non-empty, score entry filters to a single
    /// group, side games scope per-group, and photo import maps to one group's card.
    /// When empty, the round behaves as a single all-players group.
    var playingGroups: [PlayingGroup] = []

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
        matchPairings: [MatchPairing] = [],
        trackPutts: Bool = true,
        playingGroups: [PlayingGroup] = []
    ) {
        self.id = id
        self.course = course
        self.date = date
        self.formatRaw = format.rawValue
        self.playerIds = playerIds
        self.scorecards = scorecards
        self.isComplete = isComplete
        self.matchPairings = matchPairings
        self.trackPutts = trackPutts
        self.playingGroups = playingGroups
    }

    // MARK: - Playing group helpers

    /// True when the round has at least one playing group configured.
    var hasPlayingGroups: Bool { !playingGroups.isEmpty }

    /// The playing group containing the given player, if any.
    func playingGroup(containing playerId: UUID) -> PlayingGroup? {
        playingGroups.first { $0.playerIds.contains(playerId) }
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

import Foundation

/// Display row for one active side game in the trip — used by the Leaderboard's
/// "Trip Side Games" section to surface where each game stands without needing the user
/// to dig into the Side Games tab.
struct TripSideGameSummary: Identifiable, Hashable {
    let id: UUID
    /// "Skins", "Snake", "Nassau", etc.
    let gameTitle: String
    /// "Group 1 · Pine Valley" or "Trip-wide · Pine Valley" — scopes the game.
    let scopeLabel: String
    /// SF Symbol icon name.
    let iconName: String
    /// Current leader / holder / status text — e.g., "Sam holds 🐍" or "Alex · 3 skins".
    let statusLine: String
}

/// Aggregates per-side-game live state across a trip's rounds into a flat list
/// of `TripSideGameSummary` rows. Filters to active side games tied to a round
/// (trip-wide-only games still surface, scoped as such).
enum TripSideGameSummarizer {

    static func summarize(trip: Trip) -> [TripSideGameSummary] {
        trip.sideGames
            .filter { $0.isActive }
            .compactMap { game -> TripSideGameSummary? in
                guard let round = game.round else {
                    // Trip-wide games without an attached round don't have a course to score against.
                    // Skip until the user attaches them to a round (rare path).
                    return nil
                }
                let state = LiveSideGameStateEngine.state(for: game, round: round)
                let scope: String = {
                    let roundLabel = round.course?.name ?? "Round"
                    if let extra = state.scopeLabel {
                        return "\(extra) · \(roundLabel)"
                    }
                    return roundLabel
                }()
                return TripSideGameSummary(
                    id: game.id,
                    gameTitle: state.title,
                    scopeLabel: scope,
                    iconName: state.icon,
                    statusLine: state.subtitle
                )
            }
    }
}

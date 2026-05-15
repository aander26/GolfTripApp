import Foundation

/// A subset of players in a round who are physically playing together — the "foursome."
/// Used to filter score entry, scope side games and photo imports to a single on-course group,
/// and identify which group's status the user wants surfaced live.
///
/// Stored inline on `Round` (Codable struct, not @Model) following the same pattern as
/// `MatchPairing`. Optional — rounds without playing groups behave exactly as before.
struct PlayingGroup: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// Display name. Defaults to "Group N" but the trip organizer can rename ("Carts" / "Cart 1").
    var name: String = "Group"
    /// Trip player IDs in this group. Typically 2–4 players.
    var playerIds: [UUID] = []
    /// Optional designated scorer (a player in this group). When set, the score-entry UI
    /// gates editing to the device whose `appState.currentUser` maps to this player.
    var scorerPlayerId: UUID? = nil
    /// Tee time for this specific group (used for shotgun starts where groups start at
    /// different times or different holes). Falls back to `Round.date` if nil.
    var teeTime: Date? = nil
    /// Hole this group teed off from (shotgun starts). Defaults to 1.
    var startingHole: Int = 1

    init(
        id: UUID = UUID(),
        name: String = "Group",
        playerIds: [UUID] = [],
        scorerPlayerId: UUID? = nil,
        teeTime: Date? = nil,
        startingHole: Int = 1
    ) {
        self.id = id
        self.name = name
        self.playerIds = playerIds
        self.scorerPlayerId = scorerPlayerId
        self.teeTime = teeTime
        self.startingHole = startingHole
    }
}

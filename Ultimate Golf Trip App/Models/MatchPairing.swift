import Foundation

/// A single 1v1 match pairing within a round between players from opposing teams.
/// Stored as a Codable array on Round (inline, not a separate @Model).
struct MatchPairing: Identifiable, Codable, Hashable {
    var id: UUID
    var player1Id: UUID  // Player from Team A
    var player2Id: UUID  // Player from Team B
    /// When set, this match has been conceded — the named player is the winner regardless of
    /// remaining unscored holes. Engine short-circuits to a closed-out result.
    var concededWinnerId: UUID?

    init(
        id: UUID = UUID(),
        player1Id: UUID,
        player2Id: UUID,
        concededWinnerId: UUID? = nil
    ) {
        self.id = id
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.concededWinnerId = concededWinnerId
    }
}

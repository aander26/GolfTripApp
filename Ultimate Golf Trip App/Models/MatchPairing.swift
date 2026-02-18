import Foundation

/// A single 1v1 match pairing within a round between players from opposing teams.
/// Stored as a Codable array on Round (inline, not a separate @Model).
struct MatchPairing: Identifiable, Codable, Hashable {
    var id: UUID
    var player1Id: UUID  // Player from Team A
    var player2Id: UUID  // Player from Team B

    init(
        id: UUID = UUID(),
        player1Id: UUID,
        player2Id: UUID
    ) {
        self.id = id
        self.player1Id = player1Id
        self.player2Id = player2Id
    }
}

import Foundation
import SwiftData

@Model
final class SideGame {
    var id: UUID
    var typeRaw: String
    var participantIds: [UUID]
    var stakes: Double
    var stakesLabel: String
    var results: [SideGameResult]
    var isActive: Bool
    var designatedHoles: [Int]

    /// When true, stakes represents a per-player buy-in and the winner takes the full pot.
    var isPotGame: Bool

    /// The winner of a pot game (set when the pot is resolved).
    var potWinnerId: UUID?

    // Relationships
    var round: Round?
    var trip: Trip?

    init(
        id: UUID = UUID(),
        type: SideGameType,
        round: Round? = nil,
        participantIds: [UUID] = [],
        stakes: Double = 0,
        stakesLabel: String = "",
        results: [SideGameResult] = [],
        isActive: Bool = true,
        designatedHoles: [Int] = [],
        isPotGame: Bool = false,
        potWinnerId: UUID? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.round = round
        self.participantIds = participantIds
        self.stakes = stakes
        self.stakesLabel = stakesLabel.isEmpty ? (stakes > 0 ? "$\(String(format: "%.0f", stakes))" : "Bragging Rights") : stakesLabel
        self.results = results
        self.isActive = isActive
        self.designatedHoles = designatedHoles
        self.isPotGame = isPotGame
        self.potWinnerId = potWinnerId
    }

    // MARK: - Computed Properties

    var type: SideGameType {
        get { SideGameType(rawValue: typeRaw) ?? .skins }
        set { typeRaw = newValue.rawValue }
    }

    /// Backward-compat
    var roundId: UUID? { round?.id }

    var hasResults: Bool { !results.isEmpty }

    // MARK: - Pot Game Properties

    /// Total pot amount: buy-in per player x number of players
    var totalPot: Double {
        stakes * Double(participantIds.count)
    }

    /// Display text for pot games: "4 x $10 = $40 pot"
    var potDisplayText: String {
        let perPlayer = String(format: "%.0f", stakes)
        let total = String(format: "%.0f", totalPot)
        return "\(participantIds.count) x $\(perPlayer) = $\(total) pot"
    }

    /// Whether the pot game has been resolved with a winner
    var isPotResolved: Bool {
        isPotGame && potWinnerId != nil
    }

    func resultsForHole(_ holeNumber: Int) -> [SideGameResult] {
        results.filter { $0.holeNumber == holeNumber }
    }

    func resultsForPlayer(_ playerId: UUID) -> [SideGameResult] {
        results.filter { $0.winnerId == playerId }
    }

    func totalWinnings(forPlayer playerId: UUID) -> Double {
        results.filter { $0.winnerId == playerId }.reduce(0) { $0 + $1.amount }
    }

    func addResult(_ result: SideGameResult) {
        results.append(result)
    }
}

// Stays as Codable struct — small value type stored inline by SwiftData
struct SideGameResult: Identifiable, Codable, Hashable {
    var id: UUID
    var holeNumber: Int
    var winnerId: UUID?
    var amount: Double
    var description: String
    var isCarryOver: Bool

    init(
        id: UUID = UUID(),
        holeNumber: Int = 0,
        winnerId: UUID? = nil,
        amount: Double = 0,
        description: String = "",
        isCarryOver: Bool = false
    ) {
        self.id = id
        self.holeNumber = holeNumber
        self.winnerId = winnerId
        self.amount = amount
        self.description = description
        self.isCarryOver = isCarryOver
    }
}

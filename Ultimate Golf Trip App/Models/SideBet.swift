import Foundation
import SwiftData

@Model
final class SideBet {
    var id: UUID
    var name: String
    var betTypeRaw: String
    var targetValue: Double?
    var participants: [UUID]
    var stake: String
    var statusRaw: String
    var winnerId: UUID?

    /// When true, each participant puts up `potAmount` and the winner takes the total pot.
    var isPotBet: Bool
    /// Per-player buy-in amount (only used when `isPotBet` is true).
    var potAmount: Double

    // Relationships
    var metric: Metric?
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        metric: Metric? = nil,
        betType: BetType = .highestTotal,
        targetValue: Double? = nil,
        participants: [UUID] = [],
        stake: String = "Bragging Rights",
        status: BetStatus = .active,
        winnerId: UUID? = nil,
        isPotBet: Bool = false,
        potAmount: Double = 0
    ) {
        self.id = id
        self.name = name
        self.metric = metric
        self.betTypeRaw = betType.rawValue
        self.targetValue = targetValue
        self.participants = participants
        self.stake = stake
        self.statusRaw = status.rawValue
        self.winnerId = winnerId
        self.isPotBet = isPotBet
        self.potAmount = potAmount
    }

    // MARK: - Computed Properties

    var betType: BetType {
        get { BetType(rawValue: betTypeRaw) ?? .highestTotal }
        set { betTypeRaw = newValue.rawValue }
    }

    var status: BetStatus {
        get { BetStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    /// Backward-compat
    var metricId: UUID? { metric?.id }

    var isActive: Bool {
        status == .active
    }

    var isCompleted: Bool {
        status == .completed
    }

    var formattedTarget: String? {
        guard let target = targetValue else { return nil }
        if target == target.rounded() {
            return String(format: "%.0f", target)
        }
        return String(format: "%.1f", target)
    }

    var requiresTarget: Bool {
        betType == .closestToTarget || betType == .overUnder
    }

    // MARK: - Pot Properties

    /// Total pot: per-player buy-in × number of participants.
    var totalPot: Double {
        potAmount * Double(participants.count)
    }

    /// Display text: "4 x $10 = $40 pot"
    var potDisplayText: String {
        let perPlayer = String(format: "%.0f", potAmount)
        let total = String(format: "%.0f", totalPot)
        return "\(participants.count) x $\(perPlayer) = $\(total) pot"
    }
}

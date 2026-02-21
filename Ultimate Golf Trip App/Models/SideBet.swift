import Foundation
import SwiftData

/// A friendly challenge between trip participants based on a tracked metric.
/// (SwiftData class name kept as `SideBet` to preserve existing persistent stores.)
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

    /// When true, each participant contributes `potAmount` and the winner takes the total pool.
    var isPotBet: Bool
    /// Per-player entry amount (only used when `isPotBet` is true).
    var potAmount: Double

    // Relationships
    var metric: Metric?
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        metric: Metric? = nil,
        betType: ChallengeType = .highestTotal,
        targetValue: Double? = nil,
        participants: [UUID] = [],
        stake: String = "Bragging Rights",
        status: ChallengeStatus = .active,
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

    var challengeType: ChallengeType {
        get { ChallengeType(rawValue: betTypeRaw) ?? .highestTotal }
        set { betTypeRaw = newValue.rawValue }
    }

    /// Backward compatibility accessor
    var betType: ChallengeType {
        get { challengeType }
        set { challengeType = newValue }
    }

    var status: ChallengeStatus {
        get { ChallengeStatus(rawValue: statusRaw) ?? .active }
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
        challengeType == .closestToTarget || challengeType == .overUnder
    }

    // MARK: - Pool Properties

    /// Total pool: per-player entry × number of participants.
    var totalPool: Double {
        potAmount * Double(participants.count)
    }

    /// Backward compatibility accessor
    var totalPot: Double { totalPool }

    /// Display text: "4 entries × 10 pts = 40 pt pool"
    var poolDisplayText: String {
        let perPlayer = String(format: "%.0f", potAmount)
        let total = String(format: "%.0f", totalPool)
        return "\(participants.count) entries × \(perPlayer) pts = \(total) pt pool"
    }

    /// Backward compatibility accessor
    var potDisplayText: String { poolDisplayText }
}

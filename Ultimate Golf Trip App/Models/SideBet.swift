import Foundation
import SwiftData

/// A friendly challenge between trip participants.
/// (SwiftData class name kept as `SideBet` to preserve existing persistent stores.)
@Model
final class SideBet {
    var id: UUID = UUID()
    var name: String = ""
    var betTypeRaw: String = "highestTotal"
    var targetValue: Double?
    var participants: [UUID] = []
    var stake: String = "Bragging Rights"
    var statusRaw: String = "active"
    var winnerId: UUID?

    /// When true, each participant contributes `potAmount` and the winner takes the total pool.
    var isPotBet: Bool = false
    /// Per-player entry amount (only used when `isPotBet` is true).
    var potAmount: Double = 0

    /// When true, this challenge uses net scoring (after handicap strokes).
    var useNetScoring: Bool = false

    /// When true, this challenge requires putts data to be entered on the scorecard.
    var requiresPuttsData: Bool = false

    /// For custom challenges: the metric being tracked (e.g., "Beers Drank").
    var customMetricName: String = ""

    /// For custom challenges: whether highest value wins (true) or lowest (false).
    var customHighestWins: Bool = true

    /// For custom challenges: manually entered values per participant, stored as JSON.
    var customValuesRaw: String = "{}"

    // Relationships
    /// The specific round this challenge is scoped to (for round-based challenges).
    var round: Round?
    @Relationship(inverse: \Trip.sideBets)
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        betType: ChallengeType = .highestTotal,
        targetValue: Double? = nil,
        participants: [UUID] = [],
        stake: String = "Bragging Rights",
        status: ChallengeStatus = .active,
        winnerId: UUID? = nil,
        isPotBet: Bool = false,
        potAmount: Double = 0,
        round: Round? = nil,
        useNetScoring: Bool = false,
        requiresPuttsData: Bool = false
    ) {
        self.id = id
        self.name = name
        self.betTypeRaw = betType.rawValue
        self.targetValue = targetValue
        self.participants = participants
        self.stake = stake
        self.statusRaw = status.rawValue
        self.winnerId = winnerId
        self.isPotBet = isPotBet
        self.potAmount = potAmount
        self.round = round
        self.useNetScoring = useNetScoring
        self.requiresPuttsData = requiresPuttsData
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

    /// Whether this challenge is based on round scores rather than metric data.
    var isRoundBased: Bool {
        challengeType.isRoundBased
    }

    /// Display name for the associated round (if any).
    var roundDisplayName: String? {
        guard let round = round, let courseName = round.course?.name else { return nil }
        return "\(courseName) — \(round.formattedDate)"
    }

    // MARK: - Custom Challenge Values

    /// Decoded custom values dictionary.
    var customValues: [UUID: Double] {
        get {
            guard let data = customValuesRaw.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return dict.reduce(into: [:]) { result, pair in
                if let uuid = UUID(uuidString: pair.key) {
                    result[uuid] = pair.value
                }
            }
        }
        set {
            let stringDict = newValue.reduce(into: [String: Double]()) { result, pair in
                result[pair.key.uuidString] = pair.value
            }
            if let data = try? JSONEncoder().encode(stringDict),
               let json = String(data: data, encoding: .utf8) {
                customValuesRaw = json
            }
        }
    }

    /// Update a single participant's custom value.
    func updateCustomValue(for playerId: UUID, value: Double) {
        var values = customValues
        values[playerId] = value
        customValues = values
    }
}

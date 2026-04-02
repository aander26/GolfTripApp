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

    /// When true, this challenge aggregates across all trip rounds (not scoped to one round).
    var isTripWide: Bool = false

    /// Append-only log of custom entries for cumulative tracking, stored as JSON array.
    /// Each entry records who, how much, when, and an optional note.
    var customEntriesRaw: String = "[]"

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
        requiresPuttsData: Bool = false,
        isTripWide: Bool = false
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
        self.isTripWide = isTripWide
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

    /// Update a single participant's custom value (overwrites — used for single-round custom challenges).
    func updateCustomValue(for playerId: UUID, value: Double) {
        var values = customValues
        values[playerId] = value
        customValues = values
    }

    // MARK: - Scope Display

    /// Human-readable scope: "Trip-Wide" or the round/course name.
    var scopeDisplayName: String {
        if isTripWide { return "Trip-Wide" }
        return roundDisplayName ?? "Unscoped"
    }

    // MARK: - Cumulative Custom Entries (Trip-Wide)

    /// A single log entry for cumulative custom tracking.
    struct CustomEntry: Codable, Identifiable {
        var id: UUID = UUID()
        var playerId: String   // UUID string for JSON compatibility
        var value: Double
        var timestamp: Date
        var note: String?

        var playerUUID: UUID? { UUID(uuidString: playerId) }
    }

    /// Decoded entries log.
    var customEntries: [CustomEntry] {
        get {
            guard let data = customEntriesRaw.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([CustomEntry].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                customEntriesRaw = json
            }
        }
    }

    /// Add a cumulative entry and recompute running totals in customValues.
    func addCustomEntry(for playerId: UUID, value: Double, note: String? = nil) {
        var entries = customEntries
        entries.append(CustomEntry(
            playerId: playerId.uuidString,
            value: value,
            timestamp: Date(),
            note: note
        ))
        customEntries = entries

        // Recompute running totals from all entries
        var totals: [UUID: Double] = [:]
        for entry in entries {
            if let pid = entry.playerUUID {
                totals[pid, default: 0] += entry.value
            }
        }
        customValues = totals
    }

    /// Entries for a specific player, sorted by date.
    func entriesForPlayer(_ playerId: UUID) -> [CustomEntry] {
        customEntries
            .filter { $0.playerId == playerId.uuidString }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

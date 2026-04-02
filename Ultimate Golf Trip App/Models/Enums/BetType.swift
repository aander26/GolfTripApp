import Foundation

enum ChallengeType: String, Codable, CaseIterable, Identifiable {
    case highestTotal = "highestTotal"
    case lowestTotal = "lowestTotal"
    case closestToTarget = "closestToTarget"
    case overUnder = "overUnder"
    case headToHead = "headToHead"
    case lowRound = "lowRound"
    case headToHeadRound = "headToHeadRound"
    case mostBirdies = "mostBirdies"
    case fewestPutts = "fewestPutts"
    case fewest3Putts = "fewest3Putts"
    case most3Putts = "most3Putts"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highestTotal: return "Highest Total"
        case .lowestTotal: return "Lowest Total"
        case .closestToTarget: return "Closest to Target"
        case .overUnder: return "Over/Under"
        case .headToHead: return "Head to Head"
        case .lowRound: return "Low Round"
        case .headToHeadRound: return "Head-to-Head Round"
        case .mostBirdies: return "Most Birdies"
        case .fewestPutts: return "Fewest Putts"
        case .fewest3Putts: return "Fewest 3-Putts"
        case .most3Putts: return "Most 3-Putts"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .highestTotal: return "Player with the highest cumulative value wins"
        case .lowestTotal: return "Player with the lowest cumulative value wins"
        case .closestToTarget: return "Player closest to a target number wins"
        case .overUnder: return "Predict whether the total goes over or under a set number"
        case .headToHead: return "Two players go head-to-head on a metric"
        case .lowRound: return "Lowest score for a single round wins"
        case .headToHeadRound: return "Two players compare round scores head-to-head"
        case .mostBirdies: return "Player with the most birdies (or better) in a round wins"
        case .fewestPutts: return "Player with the fewest total putts in a round wins"
        case .fewest3Putts: return "Player with the fewest 3-putts in a round wins"
        case .most3Putts: return "Player with the most 3-putts in a round loses"
        case .custom: return "Track your own metric with manual entry"
        }
    }

    var icon: String {
        switch self {
        case .highestTotal: return "arrow.up.circle.fill"
        case .lowestTotal: return "arrow.down.circle.fill"
        case .closestToTarget: return "target"
        case .overUnder: return "arrow.up.arrow.down.circle.fill"
        case .headToHead: return "person.2.fill"
        case .lowRound: return "medal.fill"
        case .headToHeadRound: return "figure.golf"
        case .mostBirdies: return "bird.fill"
        case .fewestPutts: return "flag.fill"
        case .fewest3Putts: return "hand.thumbsup.fill"
        case .most3Putts: return "hand.thumbsdown.fill"
        case .custom: return "pencil.and.list.clipboard"
        }
    }

    /// Whether this challenge type is based on round scores rather than metric data.
    var isRoundBased: Bool {
        switch self {
        case .lowRound, .headToHeadRound, .mostBirdies, .fewestPutts, .fewest3Putts, .most3Putts:
            return true
        default:
            return false
        }
    }

    /// Whether this challenge type requires exactly 2 participants.
    var requiresTwoPlayers: Bool {
        self == .headToHead || self == .headToHeadRound
    }

    /// Whether this challenge type requires putts data on the scorecard.
    var requiresPuttsTracking: Bool {
        switch self {
        case .fewestPutts, .fewest3Putts, .most3Putts:
            return true
        default:
            return false
        }
    }

    /// Whether this challenge supports net/gross scoring toggle.
    var supportsNetScoring: Bool {
        switch self {
        case .lowRound, .headToHeadRound, .mostBirdies:
            return true
        default:
            return false
        }
    }

    /// Whether this is a custom manual-tracking challenge.
    var isCustom: Bool {
        self == .custom
    }

    /// Whether this challenge can span the entire trip (cumulative across rounds).
    var supportsTripWide: Bool {
        switch self {
        case .lowRound, .mostBirdies, .fewestPutts, .fewest3Putts, .most3Putts, .custom:
            return true
        default:
            return false
        }
    }

    /// Whether highest value wins (true) or lowest wins (false) for auto-settle.
    var highestWins: Bool {
        switch self {
        case .mostBirdies, .most3Putts, .highestTotal:
            return true
        default:
            return false
        }
    }
}

/// Backward compatibility alias for serialized data
typealias BetType = ChallengeType

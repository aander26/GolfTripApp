import Foundation

enum BetType: String, Codable, CaseIterable, Identifiable {
    case highestTotal = "highestTotal"
    case lowestTotal = "lowestTotal"
    case closestToTarget = "closestToTarget"
    case overUnder = "overUnder"
    case headToHead = "headToHead"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highestTotal: return "Highest Total"
        case .lowestTotal: return "Lowest Total"
        case .closestToTarget: return "Closest to Target"
        case .overUnder: return "Over/Under"
        case .headToHead: return "Head to Head"
        }
    }

    var description: String {
        switch self {
        case .highestTotal: return "Player with the highest cumulative value wins"
        case .lowestTotal: return "Player with the lowest cumulative value wins"
        case .closestToTarget: return "Player closest to a target number wins"
        case .overUnder: return "Bet on whether the total goes over or under a set number"
        case .headToHead: return "Two players go head-to-head on a metric"
        }
    }

    var icon: String {
        switch self {
        case .highestTotal: return "arrow.up.circle.fill"
        case .lowestTotal: return "arrow.down.circle.fill"
        case .closestToTarget: return "target"
        case .overUnder: return "arrow.up.arrow.down.circle.fill"
        case .headToHead: return "person.2.fill"
        }
    }
}

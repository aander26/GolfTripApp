import Foundation

enum SideGameType: String, Codable, CaseIterable, Identifiable {
    case skins = "Skins"
    case nassau = "Nassau"
    case closestToPin = "Closest to Pin"
    case longDrive = "Long Drive"
    case greenies = "Greenies"
    case dots = "Dots / Trash"
    case snake = "Snake"
    case wolf = "Wolf"
    case rabbit = "Rabbit"
    case arnies = "Arnies"
    case sandies = "Sandies"
    case barkies = "Barkies"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .skins:
            return "Win the hole outright to win the skin. Ties carry over."
        case .nassau:
            return "Three bets in one: front nine, back nine, and overall."
        case .closestToPin:
            return "Closest tee shot to the pin on designated par 3s."
        case .longDrive:
            return "Longest drive in the fairway on designated holes."
        case .greenies:
            return "Hit the green on a par 3 and closest to the pin wins if you make par or better."
        case .dots:
            return "Earn or lose points for various achievements each hole."
        case .snake:
            return "First to 3-putt holds the snake. Holder at the end pays."
        case .wolf:
            return "Rotating wolf picks a partner or goes lone wolf each hole."
        case .rabbit:
            return "Win a hole to catch the rabbit. Hold it at holes 9 and 18 to win."
        case .arnies:
            return "Make par or better without hitting the fairway."
        case .sandies:
            return "Make par or better after being in a bunker."
        case .barkies:
            return "Make par or better after hitting a tree."
        }
    }

    var isPerHole: Bool {
        switch self {
        case .closestToPin, .longDrive:
            return false
        default:
            return true
        }
    }

    var supportsCarryOver: Bool {
        switch self {
        case .skins, .rabbit:
            return true
        default:
            return false
        }
    }
}

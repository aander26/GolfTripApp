import Foundation

enum TrackingType: String, Codable, CaseIterable, Identifiable {
    case cumulative = "cumulative"
    case perRound = "perRound"
    case perDay = "perDay"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cumulative: return "Cumulative"
        case .perRound: return "Per Round"
        case .perDay: return "Per Day"
        }
    }

    var description: String {
        switch self {
        case .cumulative: return "Running total across the entire trip"
        case .perRound: return "Tracked separately for each round"
        case .perDay: return "Tracked separately for each day"
        }
    }
}

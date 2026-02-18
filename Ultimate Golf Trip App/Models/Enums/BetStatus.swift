import Foundation

enum BetStatus: String, Codable, CaseIterable, Identifiable {
    case active = "active"
    case completed = "completed"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        }
    }
}

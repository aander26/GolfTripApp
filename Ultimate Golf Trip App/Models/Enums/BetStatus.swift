import Foundation

enum ChallengeStatus: String, Codable, CaseIterable, Identifiable {
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

/// Backward compatibility alias for serialized data
typealias BetStatus = ChallengeStatus

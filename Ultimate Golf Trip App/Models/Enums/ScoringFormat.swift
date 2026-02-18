import Foundation

enum ScoringFormat: String, Codable, CaseIterable, Identifiable {
    case strokePlay = "Stroke Play"
    case matchPlay = "Match Play"
    case bestBall = "Best Ball"
    case scramble = "Scramble"
    case stableford = "Stableford"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .strokePlay:
            return "Individual stroke play with handicap adjustment"
        case .matchPlay:
            return "Hole-by-hole competition with handicap strokes"
        case .bestBall:
            return "Best net score from each team counts per hole"
        case .scramble:
            return "All players hit, team plays best shot each time"
        case .stableford:
            return "Points awarded based on net score per hole"
        }
    }

    var requiresTeams: Bool {
        switch self {
        case .strokePlay, .stableford:
            return false
        case .matchPlay, .bestBall, .scramble:
            return true
        }
    }
}

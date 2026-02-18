import Foundation

/// Defines how team competition is scored for a specific course in the trip.
/// Stored as a Codable property on Course (inline, not a separate @Model).
struct TeamScoringRule: Codable, Hashable {

    /// The team competition format for this course
    var format: TeamScoringFormat

    /// Points the winning team/player earns
    var pointsPerWin: Double

    /// Points for a halved/tied result
    var pointsPerHalve: Double

    /// Points for a loss
    var pointsPerLoss: Double

    init(
        format: TeamScoringFormat = .traditionalMatchPlay,
        pointsPerWin: Double = 1.0,
        pointsPerHalve: Double = 0.5,
        pointsPerLoss: Double = 0.0
    ) {
        self.format = format
        self.pointsPerWin = pointsPerWin
        self.pointsPerHalve = pointsPerHalve
        self.pointsPerLoss = pointsPerLoss
    }

    /// Quick description for display, e.g., "Match Play · 1.0/0.5/0.0"
    var summaryText: String {
        "\(format.shortName) · \(String(format: "%.1f", pointsPerWin))/\(String(format: "%.1f", pointsPerHalve))/\(String(format: "%.1f", pointsPerLoss))"
    }
}

// MARK: - Team Scoring Format

/// The different ways team competition can be scored for a round.
enum TeamScoringFormat: String, Codable, CaseIterable, Identifiable {
    /// Traditional match play: 1v1 hole-by-hole, win/lose/halve the match.
    /// Points awarded per match result (like Ryder Cup).
    case traditionalMatchPlay = "Traditional Match Play"

    /// Singles match play: 1v1, but earn a point for EACH hole you win.
    /// Example: Alex beats Keith on 5 holes → Alex's team gets 5 points.
    case singlesMatchPlay = "Singles Match Play"

    /// Team stroke play: compare total team net strokes.
    /// Winning team gets a fixed number of points. Can also award per-stroke margin.
    case teamStrokePlay = "Team Stroke Play"

    /// Team best ball: each team's best net score per hole.
    /// Compare team totals, winning team gets points.
    case teamBestBall = "Team Best Ball"

    var id: String { rawValue }

    /// Short display name for compact UI
    var shortName: String {
        switch self {
        case .traditionalMatchPlay: return "Match Play"
        case .singlesMatchPlay: return "Singles"
        case .teamStrokePlay: return "Stroke Play"
        case .teamBestBall: return "Best Ball"
        }
    }

    /// Longer description explaining the format
    var description: String {
        switch self {
        case .traditionalMatchPlay:
            return "1v1 hole-by-hole matches. Win, lose, or halve each match. Points awarded per match result."
        case .singlesMatchPlay:
            return "1v1 matches where you earn a point for each individual hole you win."
        case .teamStrokePlay:
            return "Compare total team net strokes. Winning team earns the defined points."
        case .teamBestBall:
            return "Best net score per hole from each team. Winning team earns the defined points."
        }
    }

    /// How points are labeled in the UI
    var pointsLabel: String {
        switch self {
        case .traditionalMatchPlay:
            return "Points per match"
        case .singlesMatchPlay:
            return "Points per hole won"
        case .teamStrokePlay:
            return "Points for winning team"
        case .teamBestBall:
            return "Points for winning team"
        }
    }

    /// Whether this format scores per-player (match play) or per-team (stroke play, best ball)
    var isPerPlayerFormat: Bool {
        switch self {
        case .traditionalMatchPlay, .singlesMatchPlay:
            return true
        case .teamStrokePlay, .teamBestBall:
            return false
        }
    }
}

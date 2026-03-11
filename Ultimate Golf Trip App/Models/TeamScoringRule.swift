import Foundation

/// Defines how team competition is scored for a specific course in the trip.
/// Stored as a Codable property on Course (inline, not a separate @Model).
struct TeamScoringRule: Codable, Hashable, Sendable {

    /// The team competition format for this course
    var format: TeamScoringFormat

    /// Points the winning team/player earns
    var pointsPerWin: Double

    /// Points for a halved/tied result
    var pointsPerHalve: Double

    /// Points for a loss
    var pointsPerLoss: Double

    /// Points for winning the front 9 (nines & overall format only).
    /// Optional so older persisted data (which lacks this field) decodes safely.
    var pointsPerNineWin: Double?

    /// Points for halving a nine (nines & overall format only)
    var pointsPerNineHalve: Double?

    /// Points for winning the overall 18 (nines & overall format only)
    var pointsPerOverallWin: Double?

    /// Points for halving the overall 18 (nines & overall format only)
    var pointsPerOverallHalve: Double?

    /// When true, scoring is split into Front 9, Back 9, and Overall segments.
    /// Always implicitly true for `ninesAndOverall` format.
    /// Optional so older persisted data decodes safely (defaults to false).
    var useNinesAndOverall: Bool?

    /// Whether nines scoring is active (true for ninesAndOverall format, or when toggled on).
    var effectiveUseNines: Bool {
        format == .ninesAndOverall || (useNinesAndOverall ?? false)
    }

    /// Safe accessors that fall back to sensible defaults when nil
    var nineWinPoints: Double { pointsPerNineWin ?? 1.0 }
    var nineHalvePoints: Double { pointsPerNineHalve ?? 0.5 }
    var overallWinPoints: Double { pointsPerOverallWin ?? 3.0 }
    var overallHalvePoints: Double { pointsPerOverallHalve ?? 1.5 }

    init(
        format: TeamScoringFormat = .traditionalMatchPlay,
        pointsPerWin: Double = 1.0,
        pointsPerHalve: Double = 0.5,
        pointsPerLoss: Double = 0.0,
        pointsPerNineWin: Double = 1.0,
        pointsPerNineHalve: Double = 0.5,
        pointsPerOverallWin: Double = 3.0,
        pointsPerOverallHalve: Double = 1.5,
        useNinesAndOverall: Bool = false
    ) {
        self.format = format
        self.pointsPerWin = pointsPerWin
        self.pointsPerHalve = pointsPerHalve
        self.pointsPerLoss = pointsPerLoss
        self.pointsPerNineWin = pointsPerNineWin
        self.pointsPerNineHalve = pointsPerNineHalve
        self.pointsPerOverallWin = pointsPerOverallWin
        self.pointsPerOverallHalve = pointsPerOverallHalve
        self.useNinesAndOverall = useNinesAndOverall
    }

    /// Quick description for display, e.g., "Match Play · 1.0/0.5/0.0"
    var summaryText: String {
        if format == .ninesAndOverall {
            return "\(format.shortName) · F9:\(String(format: "%.1f", nineWinPoints)) B9:\(String(format: "%.1f", nineWinPoints)) OA:\(String(format: "%.1f", overallWinPoints))"
        }
        var text = "\(format.shortName) · \(String(format: "%.1f", pointsPerWin))/\(String(format: "%.1f", pointsPerHalve))/\(String(format: "%.1f", pointsPerLoss))"
        if effectiveUseNines {
            text += " + F9/B9/OA"
        }
        return text
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

    /// Nines & Overall: Points awarded for winning the front 9, back 9, and overall 18.
    /// Uses net stroke comparison within each 1v1 match. Very common in casual golf.
    case ninesAndOverall = "Nines & Overall"

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
        case .ninesAndOverall: return "9s & Overall"
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
        case .ninesAndOverall:
            return "1v1 net stroke play with points for winning the front 9, back 9, and overall 18. A common casual format."
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
        case .ninesAndOverall:
            return "Points per segment"
        case .teamStrokePlay:
            return "Points for winning team"
        case .teamBestBall:
            return "Points for winning team"
        }
    }

    /// Whether this format scores per-player (match play) or per-team (stroke play, best ball)
    var isPerPlayerFormat: Bool {
        switch self {
        case .traditionalMatchPlay, .singlesMatchPlay, .ninesAndOverall:
            return true
        case .teamStrokePlay, .teamBestBall:
            return false
        }
    }
}

import Foundation

struct HandicapEngine {

    /// Convert a player's handicap index to a course handicap for a specific course
    /// Formula: Course Handicap = Handicap Index × (Slope Rating / 113) + (Course Rating - Par)
    static func courseHandicap(
        handicapIndex: Double,
        slopeRating: Double,
        courseRating: Double,
        par: Int
    ) -> Int {
        // Clamp slope to valid range (55-155). Zero or invalid slope would zero out the handicap.
        let clampedSlope = max(55.0, min(155.0, slopeRating))
        let raw = handicapIndex * (clampedSlope / 113.0) + (courseRating - Double(par))
        return Int(raw.rounded())
    }

    /// Distribute handicap strokes across holes based on hole handicap ratings.
    /// Holes with lower handicap rating numbers are the hardest and get strokes first.
    /// Returns an array of strokes received per hole (indexed by hole number 1-18).
    static func distributeStrokes(courseHandicap: Int, holes: [Hole]) -> [Int: Int] {
        var strokeMap: [Int: Int] = [:]
        let sortedHoles = holes.sorted { $0.handicapRating < $1.handicapRating }

        var remainingStrokes = abs(courseHandicap)
        let isPlus = courseHandicap < 0

        if isPlus {
            // Plus handicap: player gives strokes on easiest holes
            let reverseSorted = holes.sorted { $0.handicapRating > $1.handicapRating }
            for hole in reverseSorted {
                if remainingStrokes > 0 {
                    strokeMap[hole.number] = -1
                    remainingStrokes -= 1
                } else {
                    strokeMap[hole.number] = 0
                }
            }
        } else {
            // Regular handicap: player receives strokes on hardest holes
            // First pass: 1 stroke per hole for first 18 strokes
            for hole in sortedHoles {
                if remainingStrokes > 0 {
                    strokeMap[hole.number] = (strokeMap[hole.number] ?? 0) + 1
                    remainingStrokes -= 1
                } else {
                    strokeMap[hole.number] = strokeMap[hole.number] ?? 0
                }
            }
            // Second pass: additional stroke for handicaps > 18
            if remainingStrokes > 0 {
                for hole in sortedHoles {
                    if remainingStrokes > 0 {
                        strokeMap[hole.number] = (strokeMap[hole.number] ?? 0) + 1
                        remainingStrokes -= 1
                    }
                }
            }
        }

        // Fill in any missing holes with 0
        for hole in holes {
            if strokeMap[hole.number] == nil {
                strokeMap[hole.number] = 0
            }
        }

        return strokeMap
    }

    /// Calculate net score for each hole given gross scores and stroke distribution
    static func calculateNetScores(holeScores: [HoleScore], strokeMap: [Int: Int]) -> [HoleScore] {
        holeScores.map { score in
            var updated = score
            let strokes = strokeMap[score.holeNumber] ?? 0
            updated.strokesReceived = strokes
            updated.netStrokes = max(0, score.strokes - strokes)
            return updated
        }
    }

    /// Calculate team handicap for scramble format
    /// 2 players: 35% of low handicap + 15% of high handicap
    /// 3 players: 25% of low + 12.5% of mid + 10% of high
    /// 4 players: 25% of low + 10% each of remaining three
    static func scrambleTeamHandicap(courseHandicaps: [Int]) -> Int {
        let sorted = courseHandicaps.sorted()
        guard !sorted.isEmpty else { return 0 }

        let teamHandicap: Double
        switch sorted.count {
        case 1:
            teamHandicap = Double(sorted[0])
        case 2:
            teamHandicap = 0.35 * Double(sorted[0]) + 0.15 * Double(sorted[1])
        case 3:
            teamHandicap = 0.25 * Double(sorted[0]) + 0.125 * Double(sorted[1]) + 0.10 * Double(sorted[2])
        default:
            teamHandicap = 0.25 * Double(sorted[0]) +
                sorted.dropFirst().prefix(3).reduce(0.0) { $0 + 0.10 * Double($1) }
        }

        return Int(teamHandicap.rounded())
    }

    /// Calculate best ball handicap allowance
    /// Standard: each player uses a percentage of their course handicap
    /// Common: 100% in casual play, 90% in competition
    static func bestBallHandicap(courseHandicap: Int, allowancePercentage: Double = 1.0) -> Int {
        Int((Double(courseHandicap) * allowancePercentage).rounded())
    }

    /// For match play: calculate strokes given based on difference in handicaps
    /// The lower handicap player plays at scratch, the higher handicap player
    /// gets the difference in strokes, distributed on hardest holes
    static func matchPlayStrokesGiven(
        player1Handicap: Int,
        player2Handicap: Int
    ) -> (player1Strokes: Int, player2Strokes: Int) {
        let diff = player1Handicap - player2Handicap
        if diff > 0 {
            return (player1Strokes: diff, player2Strokes: 0)
        } else {
            return (player1Strokes: 0, player2Strokes: abs(diff))
        }
    }
}

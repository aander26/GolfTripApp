import Foundation

/// Value type used by engines to hold processed scoring data without mutating @Model objects
struct ProcessedScorecard {
    let playerId: UUID
    let holeScores: [HoleScore]
    let courseHandicap: Int
    let isComplete: Bool

    var totalGross: Int { holeScores.reduce(0) { $0 + $1.strokes } }
    var totalNet: Int { holeScores.reduce(0) { $0 + $1.netStrokes } }
    var frontNineNet: Int { holeScores.filter { $0.holeNumber <= 9 }.reduce(0) { $0 + $1.netStrokes } }
    var backNineNet: Int { holeScores.filter { $0.holeNumber > 9 }.reduce(0) { $0 + $1.netStrokes } }
    var holesCompleted: Int { holeScores.filter { $0.strokes > 0 }.count }

    func score(forHole number: Int) -> HoleScore? {
        holeScores.first { $0.holeNumber == number }
    }

    /// True when the scorecard had no player reference and playerId is a fallback.
    /// Callers (leaderboards, settlements) should exclude orphaned scorecards from rankings.
    let isOrphaned: Bool

    init(from scorecard: Scorecard, processedScores: [HoleScore]? = nil) {
        let hasPlayer = scorecard.player != nil
        self.isOrphaned = !hasPlayer
        // Use a stable fallback UUID derived from the scorecard ID rather than a random one,
        // so scores for orphaned scorecards don't silently vanish with a different UUID each time.
        // Callers should check isOrphaned before including this in leaderboards/settlements.
        self.playerId = scorecard.player?.id ?? scorecard.id
        self.holeScores = processedScores ?? scorecard.holeScores
        self.courseHandicap = scorecard.courseHandicap
        self.isComplete = scorecard.isComplete
    }
}

struct ProcessedRound {
    let scorecards: [ProcessedScorecard]
}

struct ScoringEngine {

    // MARK: - Stroke Play

    /// Calculate stroke play results with handicap adjustment — returns a value-type snapshot
    static func calculateStrokePlay(
        scorecard: Scorecard,
        holes: [Hole]
    ) -> ProcessedScorecard {
        let strokeMap = HandicapEngine.distributeStrokes(
            courseHandicap: scorecard.courseHandicap,
            holes: holes
        )
        let processedScores = HandicapEngine.calculateNetScores(
            holeScores: scorecard.holeScores,
            strokeMap: strokeMap
        )
        return ProcessedScorecard(from: scorecard, processedScores: processedScores)
    }

    // MARK: - Stableford

    static func stablefordPoints(netScore: Int, par: Int) -> Int {
        guard netScore > 0 else { return 0 }
        let diff = netScore - par
        switch diff {
        case ...(-3): return 5
        case -2: return 4
        case -1: return 3
        case 0: return 2
        case 1: return 1
        default: return 0
        }
    }

    static func calculateStablefordTotal(scorecard: Scorecard, holes: [Hole]) -> Int {
        let adjusted = calculateStrokePlay(scorecard: scorecard, holes: holes)
        return adjusted.holeScores.reduce(0) { total, score in
            guard score.isCompleted else { return total }
            return total + stablefordPoints(netScore: score.netStrokes, par: score.par)
        }
    }

    // MARK: - Match Play

    /// Calculate match play result using proper handicap rules:
    /// 1. Apply 90% allowance to each player's course handicap
    /// 2. Lowest adjusted handicap plays scratch (subtract minimum from both)
    /// 3. Distribute remaining strokes by hole stroke index (hardest holes first)
    /// 4. Compare net scores hole-by-hole (win/lose/halve)
    static func calculateMatchPlay(
        player1Card: Scorecard,
        player2Card: Scorecard,
        holes: [Hole]
    ) -> MatchPlayResult {
        let p1Id = player1Card.player?.id ?? player1Card.id
        let p2Id = player2Card.player?.id ?? player2Card.id

        let totalHoles = holes.count
        guard totalHoles > 0 else {
            return MatchPlayResult(
                player1Id: p1Id,
                player2Id: p2Id,
                player1Wins: 0,
                player2Wins: 0,
                holesPlayed: 0,
                totalHoles: 0,
                result: "No holes"
            )
        }

        // Step 1: Apply 90% allowance
        let p1Adjusted = HandicapEngine.bestBallHandicap(courseHandicap: player1Card.courseHandicap, allowancePercentage: 0.9)
        let p2Adjusted = HandicapEngine.bestBallHandicap(courseHandicap: player2Card.courseHandicap, allowancePercentage: 0.9)

        // Step 2: Lowest plays scratch
        let lowest = min(p1Adjusted, p2Adjusted)
        let p1Net = p1Adjusted - lowest
        let p2Net = p2Adjusted - lowest

        // Step 3: Distribute strokes by hole stroke index
        let p1StrokeMap = HandicapEngine.distributeStrokes(courseHandicap: p1Net, holes: holes)
        let p2StrokeMap = HandicapEngine.distributeStrokes(courseHandicap: p2Net, holes: holes)

        var p1Wins = 0
        var p2Wins = 0
        var holesPlayed = 0

        for holeNum in 1...totalHoles {
            guard let score1 = player1Card.score(forHole: holeNum),
                  let score2 = player2Card.score(forHole: holeNum),
                  score1.isCompleted && score2.isCompleted else { continue }

            holesPlayed += 1

            // Net score = gross - match play strokes received on this hole
            let p1Net = score1.strokes - (p1StrokeMap[holeNum] ?? 0)
            let p2Net = score2.strokes - (p2StrokeMap[holeNum] ?? 0)

            if p1Net < p2Net {
                p1Wins += 1
            } else if p2Net < p1Net {
                p2Wins += 1
            }

            let margin = abs(p1Wins - p2Wins)
            let remaining = totalHoles - holesPlayed
            if margin > remaining { break }
        }

        let result: String
        let margin = abs(p1Wins - p2Wins)
        let remaining = totalHoles - holesPlayed

        if p1Wins == p2Wins {
            result = "All Square"
        } else if margin > remaining {
            let winner = p1Wins > p2Wins ? "P1" : "P2"
            result = remaining == 0 ? "\(winner) wins \(margin) UP" : "\(winner) wins \(margin) & \(remaining)"
        } else {
            let leader = p1Wins > p2Wins ? "P1" : "P2"
            result = "\(leader) \(margin) UP thru \(holesPlayed)"
        }

        return MatchPlayResult(
            player1Id: p1Id,
            player2Id: p2Id,
            player1Wins: p1Wins,
            player2Wins: p2Wins,
            holesPlayed: holesPlayed,
            totalHoles: totalHoles,
            result: result
        )
    }

    // MARK: - Best Ball

    static func bestBallScore(teamScorecards: [Scorecard], holeNumber: Int) -> Int? {
        let scores = teamScorecards.compactMap { card -> Int? in
            guard let score = card.score(forHole: holeNumber), score.isCompleted else { return nil }
            return score.netStrokes
        }
        return scores.min()
    }

    static func bestBallTotal(teamScorecards: [Scorecard], holes: [Hole]) -> Int {
        var total = 0
        for hole in holes {
            if let best = bestBallScore(teamScorecards: teamScorecards, holeNumber: hole.number) {
                total += best
            }
        }
        return total
    }

    // MARK: - Scramble

    static func calculateScramble(
        teamGrossScores: [Int],
        teamCourseHandicaps: [Int],
        holes: [Hole]
    ) -> (netTotal: Int, grossTotal: Int, teamHandicap: Int) {
        let teamHandicap = HandicapEngine.scrambleTeamHandicap(courseHandicaps: teamCourseHandicaps)
        let grossTotal = teamGrossScores.reduce(0, +)
        let netTotal = grossTotal - teamHandicap
        return (netTotal: netTotal, grossTotal: grossTotal, teamHandicap: teamHandicap)
    }

    // MARK: - Score to Par

    static func scoreToPar(scorecard: ProcessedScorecard) -> Int {
        scorecard.holeScores.filter { $0.isCompleted }.reduce(0) { $0 + $1.scoreToPar }
    }

    static func netScoreToPar(scorecard: ProcessedScorecard) -> Int {
        scorecard.holeScores.filter { $0.isCompleted }.reduce(0) { $0 + $1.netScoreToPar }
    }

    // MARK: - Full Round Processing

    /// Process an entire round — returns value-type ProcessedRound (does not mutate @Model objects)
    static func processRound(round: Round, course: Course) -> ProcessedRound {
        let processed = round.scorecards.map { card in
            calculateStrokePlay(scorecard: card, holes: course.holes)
        }
        return ProcessedRound(scorecards: processed)
    }
}

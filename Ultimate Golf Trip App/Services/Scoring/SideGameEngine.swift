import Foundation

struct SideGameEngine {

    // MARK: - Skins

    /// Calculate skins results using processed (net) scorecards
    static func calculateSkins(
        scorecards: [ProcessedScorecard],
        stakes: Double,
        holes: [Hole]
    ) -> [SideGameResult] {
        var results: [SideGameResult] = []
        var carryOver = 0
        let perSkin = stakes

        for hole in holes {
            let holeNum = hole.number
            let scores = scorecards.compactMap { card -> (playerId: UUID, net: Int)? in
                guard let score = card.score(forHole: holeNum), score.isCompleted else { return nil }
                return (playerId: card.playerId, net: score.netStrokes)
            }

            guard !scores.isEmpty else { continue }

            let minScore = scores.min(by: { $0.net < $1.net })!.net
            let winners = scores.filter { $0.net == minScore }

            if winners.count == 1 {
                let totalValue = perSkin * Double(1 + carryOver)
                results.append(SideGameResult(
                    holeNumber: holeNum,
                    winnerId: winners[0].playerId,
                    amount: totalValue,
                    description: carryOver > 0 ? "Won skin + \(carryOver) carryover(s)" : "Won skin"
                ))
                carryOver = 0
            } else {
                carryOver += 1
                results.append(SideGameResult(
                    holeNumber: holeNum,
                    winnerId: nil,
                    amount: 0,
                    description: "Push - skin carries over",
                    isCarryOver: true
                ))
            }
        }

        return results
    }

    // MARK: - Nassau

    /// Calculate Nassau results using processed (net) scorecards
    static func calculateNassau(
        scorecards: [ProcessedScorecard],
        stakes: Double
    ) -> [SideGameResult] {
        var results: [SideGameResult] = []

        for card1Index in 0..<scorecards.count {
            for card2Index in (card1Index + 1)..<scorecards.count {
                let card1 = scorecards[card1Index]
                let card2 = scorecards[card2Index]

                // Front 9
                let front1 = card1.frontNineNet
                let front2 = card2.frontNineNet
                if front1 != front2 {
                    let winnerId = front1 < front2 ? card1.playerId : card2.playerId
                    results.append(SideGameResult(
                        holeNumber: 9,
                        winnerId: winnerId,
                        amount: stakes,
                        description: "Front 9 winner"
                    ))
                }

                // Back 9
                let back1 = card1.backNineNet
                let back2 = card2.backNineNet
                if back1 != back2 {
                    let winnerId = back1 < back2 ? card1.playerId : card2.playerId
                    results.append(SideGameResult(
                        holeNumber: 18,
                        winnerId: winnerId,
                        amount: stakes,
                        description: "Back 9 winner"
                    ))
                }

                // Overall
                let total1 = card1.totalNet
                let total2 = card2.totalNet
                if total1 != total2 {
                    let winnerId = total1 < total2 ? card1.playerId : card2.playerId
                    results.append(SideGameResult(
                        holeNumber: 0,
                        winnerId: winnerId,
                        amount: stakes,
                        description: "Overall winner"
                    ))
                }
            }
        }

        return results
    }

    // MARK: - Closest to Pin

    static func closestToPin(
        holeNumber: Int,
        winnerId: UUID,
        distance: String,
        stakes: Double
    ) -> SideGameResult {
        SideGameResult(
            holeNumber: holeNumber,
            winnerId: winnerId,
            amount: stakes,
            description: "Closest to pin: \(distance)"
        )
    }

    // MARK: - Long Drive

    static func longDrive(
        holeNumber: Int,
        winnerId: UUID,
        stakes: Double
    ) -> SideGameResult {
        SideGameResult(
            holeNumber: holeNumber,
            winnerId: winnerId,
            amount: stakes,
            description: "Long drive winner"
        )
    }

    // MARK: - Greenies

    static func calculateGreenies(
        scorecards: [Scorecard],
        parThreeHoles: [Int],
        greenieWinners: [Int: UUID],
        stakes: Double
    ) -> [SideGameResult] {
        var results: [SideGameResult] = []

        for holeNum in parThreeHoles {
            guard let winnerId = greenieWinners[holeNum] else { continue }

            if let card = scorecards.first(where: { $0.player?.id == winnerId }),
               let score = card.score(forHole: holeNum),
               score.isCompleted && score.netStrokes <= score.par {
                results.append(SideGameResult(
                    holeNumber: holeNum,
                    winnerId: winnerId,
                    amount: stakes,
                    description: "Greenie on hole \(holeNum)"
                ))
            }
        }

        return results
    }

    // MARK: - Dots / Trash

    enum DotType: String, CaseIterable {
        case birdie = "Birdie"
        case eagle = "Eagle"
        case greenInRegulation = "GIR"
        case sandy = "Sandy"
        case poley = "Up & Down"
        case threePutt = "3-Putt"
        case outOfBounds = "OB"
        case water = "Water"

        var points: Int {
            switch self {
            case .birdie: return 1
            case .eagle: return 2
            case .greenInRegulation: return 1
            case .sandy: return 1
            case .poley: return 1
            case .threePutt: return -1
            case .outOfBounds: return -1
            case .water: return -1
            }
        }
    }

    static func calculateDots(
        scorecard: Scorecard,
        dots: [Int: [DotType]]
    ) -> Int {
        var total = 0
        for (_, dotTypes) in dots {
            total += dotTypes.reduce(0) { $0 + $1.points }
        }
        return total
    }

    // MARK: - Snake

    /// Track the snake (3-putt tracker). Uses raw Scorecard @Model objects for putt data.
    static func calculateSnake(
        scorecards: [Scorecard],
        stakes: Double
    ) -> [SideGameResult] {
        var results: [SideGameResult] = []
        var currentSnakeHolder: UUID?

        for holeNum in 1...18 {
            for card in scorecards {
                if let score = card.score(forHole: holeNum),
                   score.isCompleted && score.putts >= 3 {
                    currentSnakeHolder = card.player?.id
                    results.append(SideGameResult(
                        holeNumber: holeNum,
                        winnerId: nil,
                        amount: 0,
                        description: "3-putt - holds the snake"
                    ))
                }
            }
        }

        if let holder = currentSnakeHolder {
            let otherPlayers = scorecards.filter { $0.player?.id != holder }.count
            results.append(SideGameResult(
                holeNumber: 18,
                winnerId: holder,
                amount: -stakes * Double(otherPlayers),
                description: "Holds snake at end - pays \(otherPlayers) player(s)"
            ))
        }

        return results
    }

    // MARK: - Wolf

    struct WolfHoleResult {
        var holeNumber: Int
        var wolfId: UUID
        var partnerId: UUID?
        var isLoneWolf: Bool
        var isBlindWolf: Bool
        var wolfTeamScore: Int
        var otherTeamScore: Int
        var wolfWins: Bool
    }

    // MARK: - Rabbit

    /// Calculate rabbit game using processed (net) scorecards
    static func calculateRabbit(
        scorecards: [ProcessedScorecard],
        stakes: Double,
        holes: [Hole]
    ) -> [SideGameResult] {
        var results: [SideGameResult] = []
        var rabbitHolder: UUID?

        for hole in holes {
            let holeNum = hole.number
            let scores = scorecards.compactMap { card -> (playerId: UUID, net: Int)? in
                guard let score = card.score(forHole: holeNum), score.isCompleted else { return nil }
                return (playerId: card.playerId, net: score.netStrokes)
            }

            guard !scores.isEmpty else { continue }
            let minScore = scores.min(by: { $0.net < $1.net })!.net
            let winners = scores.filter { $0.net == minScore }

            if winners.count == 1 {
                rabbitHolder = winners[0].playerId
                results.append(SideGameResult(
                    holeNumber: holeNum,
                    winnerId: winners[0].playerId,
                    amount: 0,
                    description: "Catches the rabbit"
                ))
            } else if winners.count > 1 {
                rabbitHolder = nil
                results.append(SideGameResult(
                    holeNumber: holeNum,
                    winnerId: nil,
                    amount: 0,
                    description: "Tie - rabbit is free"
                ))
            }

            if (holeNum == 9 || holeNum == 18), let holder = rabbitHolder {
                results.append(SideGameResult(
                    holeNumber: holeNum,
                    winnerId: holder,
                    amount: stakes,
                    description: holeNum == 9 ? "Holds rabbit at the turn" : "Holds rabbit at 18"
                ))
                rabbitHolder = nil
            }
        }

        return results
    }

    // MARK: - Arnies, Sandies, Barkies

    static func awardAchievement(
        type: SideGameType,
        holeNumber: Int,
        playerId: UUID,
        scorecard: Scorecard,
        stakes: Double
    ) -> SideGameResult? {
        guard let score = scorecard.score(forHole: holeNumber),
              score.isCompleted,
              score.strokes <= score.par else { return nil }

        return SideGameResult(
            holeNumber: holeNumber,
            winnerId: playerId,
            amount: stakes,
            description: "\(type.rawValue) on hole \(holeNumber)"
        )
    }
}

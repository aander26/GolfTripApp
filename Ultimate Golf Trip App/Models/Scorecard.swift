import Foundation
import SwiftData

@Model
final class Scorecard {
    var id: UUID
    var holeScores: [HoleScore]
    var courseHandicap: Int
    var isComplete: Bool

    // Relationships
    var round: Round?
    var player: Player?

    init(
        id: UUID = UUID(),
        round: Round? = nil,
        player: Player? = nil,
        holeScores: [HoleScore] = [],
        courseHandicap: Int = 0,
        isComplete: Bool = false
    ) {
        self.id = id
        self.round = round
        self.player = player
        self.holeScores = holeScores
        self.courseHandicap = courseHandicap
        self.isComplete = isComplete
    }

    // MARK: - Backward-compat UUID accessors

    var roundId: UUID? { round?.id }
    var playerId: UUID? { player?.id }

    // MARK: - Computed Properties

    var totalGross: Int {
        holeScores.reduce(0) { $0 + $1.strokes }
    }

    var totalNet: Int {
        holeScores.reduce(0) { $0 + $1.netStrokes }
    }

    var frontNineGross: Int {
        holeScores.filter { $0.holeNumber <= 9 }.reduce(0) { $0 + $1.strokes }
    }

    var backNineGross: Int {
        holeScores.filter { $0.holeNumber > 9 }.reduce(0) { $0 + $1.strokes }
    }

    var frontNineNet: Int {
        holeScores.filter { $0.holeNumber <= 9 }.reduce(0) { $0 + $1.netStrokes }
    }

    var backNineNet: Int {
        holeScores.filter { $0.holeNumber > 9 }.reduce(0) { $0 + $1.netStrokes }
    }

    var holesCompleted: Int {
        holeScores.filter { $0.strokes > 0 }.count
    }

    var totalPutts: Int {
        holeScores.reduce(0) { $0 + $1.putts }
    }

    func score(forHole number: Int) -> HoleScore? {
        holeScores.first { $0.holeNumber == number }
    }

    func updateScore(forHole number: Int, strokes: Int, putts: Int = 0) {
        if let index = holeScores.firstIndex(where: { $0.holeNumber == number }) {
            holeScores[index].strokes = strokes
            holeScores[index].putts = putts
        }
    }

    static func createEmpty(round: Round?, player: Player?, courseHandicap: Int, holes: [Hole]) -> Scorecard {
        let holeScores = holes.map { hole in
            HoleScore(
                holeNumber: hole.number,
                par: hole.par,
                strokes: 0,
                netStrokes: 0,
                strokesReceived: 0,
                putts: 0
            )
        }
        return Scorecard(
            round: round,
            player: player,
            holeScores: holeScores,
            courseHandicap: courseHandicap
        )
    }
}

// Stays as Codable struct — small value type stored inline by SwiftData
struct HoleScore: Identifiable, Codable, Hashable {
    var id: UUID
    var holeNumber: Int
    var par: Int
    var strokes: Int
    var netStrokes: Int
    var strokesReceived: Int
    var putts: Int

    init(
        id: UUID = UUID(),
        holeNumber: Int,
        par: Int = 4,
        strokes: Int = 0,
        netStrokes: Int = 0,
        strokesReceived: Int = 0,
        putts: Int = 0
    ) {
        self.id = id
        self.holeNumber = holeNumber
        self.par = par
        self.strokes = strokes
        self.netStrokes = netStrokes
        self.strokesReceived = strokesReceived
        self.putts = putts
    }

    var scoreToPar: Int {
        guard strokes > 0 else { return 0 }
        return strokes - par
    }

    var netScoreToPar: Int {
        guard netStrokes > 0 else { return 0 }
        return netStrokes - par
    }

    var scoreLabel: String {
        guard strokes > 0 else { return "-" }
        let diff = scoreToPar
        switch diff {
        case ...(-3): return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case 3: return "Triple Bogey"
        default: return "+\(diff)"
        }
    }

    var isCompleted: Bool { strokes > 0 }
}

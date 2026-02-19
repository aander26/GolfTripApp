import Foundation
import SwiftUI

@Observable
class ScorecardViewModel {
    var appState: AppState

    var selectedCourseId: UUID?
    var selectedFormat: ScoringFormat = .strokePlay
    var selectedPlayerIds: Set<UUID> = []
    var selectedRoundId: UUID?
    var currentHole: Int = 1
    var showingRoundSetup = false

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? { appState.currentTrip }

    var selectedCourse: Course? {
        guard let id = selectedCourseId else { return nil }
        return currentTrip?.course(withId: id)
    }

    var currentRound: Round? {
        if let selectedId = selectedRoundId,
           let round = currentTrip?.round(withId: selectedId) {
            return round
        }
        return currentTrip?.activeRound ?? currentTrip?.rounds.last { !$0.isComplete }
    }

    // MARK: - Round Setup

    func startNewRound() {
        guard let trip = currentTrip,
              let courseId = selectedCourseId,
              let course = trip.course(withId: courseId) else { return }

        let playerIds = Array(selectedPlayerIds)

        let round = Round(
            course: course,
            format: selectedFormat,
            playerIds: playerIds
        )

        let scorecards = playerIds.compactMap { playerId -> Scorecard? in
            guard let player = trip.player(withId: playerId) else { return nil }
            let courseHandicap = HandicapEngine.courseHandicap(
                handicapIndex: player.handicapIndex,
                slopeRating: course.slopeRating,
                courseRating: course.courseRating,
                par: course.totalPar
            )
            return Scorecard.createEmpty(
                round: round,
                player: player,
                courseHandicap: courseHandicap,
                holes: course.holes
            )
        }

        round.scorecards = scorecards
        round.trip = trip
        trip.rounds.append(round)
        appState.saveContext()
        currentHole = 1
        showingRoundSetup = false
    }

    // MARK: - Score Entry

    func updateScore(roundId: UUID, playerId: UUID, holeNumber: Int, strokes: Int, putts: Int = 0) {
        guard let trip = currentTrip,
              let round = trip.rounds.first(where: { $0.id == roundId }),
              let card = round.scorecards.first(where: { $0.player?.id == playerId }),
              let course = round.course else { return }

        card.updateScore(
            forHole: holeNumber,
            strokes: strokes,
            putts: putts
        )

        // Recalculate net scores
        let strokeMap = HandicapEngine.distributeStrokes(
            courseHandicap: card.courseHandicap,
            holes: course.holes
        )
        card.holeScores = HandicapEngine.calculateNetScores(
            holeScores: card.holeScores,
            strokeMap: strokeMap
        )

        // Check if round is complete
        let allComplete = round.scorecards.allSatisfy { sc in
            sc.holeScores.allSatisfy { $0.isCompleted }
        }
        if allComplete {
            round.isComplete = true
            for sc in round.scorecards {
                sc.isComplete = true
            }
        }

        appState.saveContext()
    }

    func nextHole() {
        if currentHole < 18 {
            currentHole += 1
        }
    }

    func previousHole() {
        if currentHole > 1 {
            currentHole -= 1
        }
    }

    func goToHole(_ hole: Int) {
        currentHole = max(1, min(18, hole))
    }

    // MARK: - Round Completion

    func completeRound(_ roundId: UUID) {
        guard let trip = currentTrip,
              let round = trip.rounds.first(where: { $0.id == roundId }) else { return }

        round.isComplete = true
        for sc in round.scorecards {
            sc.isComplete = true
        }
        appState.saveContext()
    }

    // MARK: - Round Selection

    func selectRound(_ round: Round) {
        selectedRoundId = round.id
        currentHole = 1
    }

    // MARK: - Helpers

    func scoreForPlayer(_ playerId: UUID, roundId: UUID, holeNumber: Int) -> HoleScore? {
        guard let trip = currentTrip,
              let round = trip.round(withId: roundId),
              let card = round.scorecard(forPlayer: playerId) else { return nil }
        return card.score(forHole: holeNumber)
    }

    func totalForPlayer(_ playerId: UUID, roundId: UUID) -> (gross: Int, net: Int) {
        guard let trip = currentTrip,
              let round = trip.round(withId: roundId),
              let card = round.scorecard(forPlayer: playerId) else { return (0, 0) }
        return (card.totalGross, card.totalNet)
    }

    func resetRoundSetup() {
        selectedCourseId = nil
        selectedFormat = .strokePlay
        selectedPlayerIds = []
    }
}

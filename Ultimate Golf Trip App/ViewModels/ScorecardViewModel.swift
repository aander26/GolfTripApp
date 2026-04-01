import Foundation
import SwiftUI

@MainActor @Observable
class ScorecardViewModel {
    var appState: AppState

    var selectedCourseId: UUID?
    var selectedFormat: ScoringFormat = .strokePlay {
        didSet {
            if selectedFormat != oldValue {
                updateTeamScoringDefault()
            }
        }
    }
    var selectedPlayerIds: Set<UUID> = []
    var selectedRoundId: UUID?
    /// When true, the user explicitly backed out to the rounds list; suppresses auto-selection of active rounds.
    var showingRoundsList = false
    var currentHole: Int = 1
    var showingRoundSetup = false
    var showingRoundComplete = false
    var showingPuttsRequiredAlert = false
    var showingMissingStrokesAlert = false

    // Team scoring options (configured during round setup)
    var selectedTeamScoringFormat: TeamScoringFormat = .traditionalMatchPlay
    var teamPointsPerWin: String = "1.0"
    var teamPointsPerHalve: String = "0.5"
    var teamPointsPerLoss: String = "0.0"
    var teamPointsPerNineWin: String = "1.0"
    var teamPointsPerNineHalve: String = "0.5"
    var teamPointsPerOverallWin: String = "3.0"
    var teamPointsPerOverallHalve: String = "1.5"
    var teamUseNinesAndOverall: Bool = false

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
        // Don't auto-select a round if the user explicitly backed out to the rounds list
        if showingRoundsList {
            return nil
        }
        return currentTrip?.activeRound ?? currentTrip?.rounds.last { !$0.isComplete }
    }

    /// Number of holes for the current round's course (defaults to 18, minimum 1)
    var holeCount: Int {
        let count = currentRound?.course?.holes.count ?? 18
        return max(count, 1)
    }

    // MARK: - Format Defaults

    /// Update the team scoring format to a sensible default when the round format changes.
    private func updateTeamScoringDefault() {
        switch selectedFormat {
        case .bestBall:
            selectedTeamScoringFormat = .teamBestBall
        case .matchPlay:
            selectedTeamScoringFormat = .traditionalMatchPlay
        case .scramble:
            selectedTeamScoringFormat = .teamStrokePlay
        case .strokePlay, .stableford:
            break
        }
    }

    // MARK: - Round Setup

    func startNewRound() {
        guard let trip = currentTrip,
              let courseId = selectedCourseId,
              let course = trip.course(withId: courseId) else { return }

        let playerIds = Array(selectedPlayerIds)
        guard !playerIds.isEmpty else { return }

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

        // Apply team scoring rule to the course if a team format is selected
        if selectedFormat.requiresTeams {
            let useNines = selectedTeamScoringFormat == .ninesAndOverall || teamUseNinesAndOverall
            let rule = TeamScoringRule(
                format: selectedTeamScoringFormat,
                pointsPerWin: Double(teamPointsPerWin) ?? 1.0,
                pointsPerHalve: Double(teamPointsPerHalve) ?? 0.5,
                pointsPerLoss: Double(teamPointsPerLoss) ?? 0.0,
                pointsPerNineWin: useNines ? (Double(teamPointsPerNineWin) ?? 1.0) : 1.0,
                pointsPerNineHalve: useNines ? (Double(teamPointsPerNineHalve) ?? 0.5) : 0.5,
                pointsPerOverallWin: useNines ? (Double(teamPointsPerOverallWin) ?? 3.0) : 3.0,
                pointsPerOverallHalve: useNines ? (Double(teamPointsPerOverallHalve) ?? 1.5) : 1.5,
                useNinesAndOverall: teamUseNinesAndOverall
            )
            course.teamScoringRule = rule
        }

        appState.saveContext()
        currentHole = 1
        showingRoundsList = false
        showingRoundSetup = false
    }

    // MARK: - Score Entry

    /// Last error from a failed score update, surfaced in the UI via an alert.
    var scoreUpdateError: String?

    /// Returns true on success, false on failure (sets scoreUpdateError).
    @discardableResult
    func updateScore(roundId: UUID, playerId: UUID, holeNumber: Int, strokes: Int, putts: Int = 0) -> Bool {
        guard strokes >= 0 else {
            scoreUpdateError = "Invalid stroke count."
            return false
        }
        guard let trip = currentTrip else {
            scoreUpdateError = "No active trip. Please select a trip first."
            return false
        }
        guard let round = trip.rounds.first(where: { $0.id == roundId }) else {
            scoreUpdateError = "Round not found. It may have been deleted."
            return false
        }
        guard let card = round.scorecards.first(where: { $0.player?.id == playerId }) else {
            scoreUpdateError = "Scorecard not found for this player."
            return false
        }
        guard let course = round.course else {
            scoreUpdateError = "No course assigned to this round."
            return false
        }

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

        // Touch the round's updatedAt so merge conflict resolution prefers this version
        round.updatedAt = Date()

        appState.saveContext()
        scoreUpdateError = nil
        return true
    }

    func nextHole() {
        guard currentHole < holeCount else { return }
        if validateCurrentHole() {
            currentHole += 1
        }
    }

    func previousHole() {
        if currentHole > 1 {
            currentHole -= 1
        }
    }

    func goToHole(_ hole: Int) {
        let target = max(1, min(holeCount, hole))
        // Only validate when moving forward
        if target > currentHole {
            guard validateCurrentHole() else { return }
        }
        currentHole = target
    }

    // MARK: - Challenge-Based Validation

    /// Whether any active challenge for the current round requires putts data.
    var puttsRequiredForCurrentRound: Bool {
        guard let round = currentRound,
              let trip = currentTrip else { return false }
        return trip.activeSideBets.contains { bet in
            bet.round?.id == round.id && bet.requiresPuttsData
        }
    }

    /// Names of active challenges requiring putts for display in the alert.
    var puttsRequiredChallengeNames: [String] {
        guard let round = currentRound,
              let trip = currentTrip else { return [] }
        return trip.activeSideBets
            .filter { $0.round?.id == round.id && $0.requiresPuttsData }
            .map(\.name)
    }

    /// Validates the current hole's data before allowing navigation forward.
    /// Returns true if OK to proceed, false if validation failed (alert shown).
    private func validateCurrentHole() -> Bool {
        guard let round = currentRound else { return true }

        // Check if any player is missing strokes for the current hole
        let missingStrokes = round.scorecards.contains { card in
            guard let score = card.score(forHole: currentHole) else { return true }
            return score.strokes == 0
        }

        if missingStrokes {
            showingMissingStrokesAlert = true
            return false
        }

        // Check if any active challenge requires putts
        if puttsRequiredForCurrentRound {
            let needsPutts = round.scorecards.contains { card in
                guard let score = card.score(forHole: currentHole) else { return false }
                return score.strokes > 0 && score.putts == 0
            }

            if needsPutts {
                showingPuttsRequiredAlert = true
                return false
            }
        }

        return true
    }

    // MARK: - Round Completion

    func completeRound(_ roundId: UUID) {
        guard let trip = currentTrip,
              let round = trip.rounds.first(where: { $0.id == roundId }) else { return }

        round.isComplete = true
        for sc in round.scorecards {
            // Only mark complete if the player actually has scores entered
            if sc.holesCompleted > 0 {
                sc.isComplete = true
            }
        }

        // Auto-settle any active round-based challenges tied to this round
        for bet in trip.activeSideBets where bet.isRoundBased && bet.round?.id == roundId {
            let winnerId = ChallengesViewModel.determineRoundBasedWinner(for: bet, round: round)
            trip.completeSideBet(id: bet.id, winnerId: winnerId)
        }

        appState.saveContext()
    }

    // MARK: - Round Deletion

    func deleteRound(_ roundId: UUID) {
        guard let trip = currentTrip else { return }
        if selectedRoundId == roundId {
            selectedRoundId = nil
        }
        trip.removeRound(id: roundId)
        appState.saveContext()
    }

    // MARK: - Round Selection

    func selectRound(_ round: Round) {
        selectedRoundId = round.id
        showingRoundsList = false
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
        selectedTeamScoringFormat = .traditionalMatchPlay
        teamPointsPerWin = "1.0"
        teamPointsPerHalve = "0.5"
        teamPointsPerLoss = "0.0"
        teamPointsPerNineWin = "1.0"
        teamPointsPerNineHalve = "0.5"
        teamPointsPerOverallWin = "3.0"
        teamPointsPerOverallHalve = "1.5"
        teamUseNinesAndOverall = false
    }
}

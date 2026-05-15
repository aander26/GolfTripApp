import Foundation
import SwiftUI
import UIKit

@MainActor @Observable
final class ScorecardImportViewModel: Identifiable {
    /// Stable id so this view model can drive `.sheet(item:)`.
    nonisolated let id: UUID = UUID()

    enum Step {
        case capture
        case parsing
        case review
        case noHeader   // OCR succeeded but we couldn't locate the hole-number header — ask for retake
        case failed(String)
    }

    /// Live step shown by the flow view.
    var step: Step = .capture

    /// The photo the user picked / captured.
    var image: UIImage?

    /// Parsed scorecard (rows + cells). Populated after OCR.
    var parsed: ParsedScorecard?

    /// User-chosen player for each row, keyed by row id. nil = row will be ignored on apply.
    var playerByRow: [UUID: UUID] = [:]

    /// Optional scope: when the round has playing groups, this restricts `availablePlayers` to
    /// a single group so player pickers don't have to scroll through the whole roster. Defaults
    /// to the current user's group when present. `nil` = show every player in the round.
    var scopedGroupId: UUID? = nil

    /// User-overridden strokes per (rowId, holeNumber). Takes precedence over OCR.
    var overrides: [String: Int] = [:]

    /// Cells the user has explicitly confirmed (clears the flag/yellow highlight).
    var confirmedCells: Set<String> = []

    /// The round we're importing into.
    private(set) var roundId: UUID
    private(set) var courseId: UUID
    let holeCount: Int

    /// Reference to the scoring view model — used on Apply to write scores via the existing pipeline.
    private weak var scorecardVM: ScorecardViewModel?

    init(scorecardVM: ScorecardViewModel, round: Round, course: Course) {
        self.scorecardVM = scorecardVM
        self.roundId = round.id
        self.courseId = course.id
        self.holeCount = max(course.holes.count, 1)

        // Default the scope to the current user's playing group, if the round has groups
        // and the user is in one. The user can change it on the review screen.
        if let trip = scorecardVM.currentTrip,
           let me = scorecardVM.appState.myPlayer(in: trip),
           let myGroup = round.playingGroup(containing: me.id) {
            self.scopedGroupId = myGroup.id
        }
    }

    // MARK: - Playing-group scope

    /// All playing groups defined on the round (empty if none).
    var playingGroups: [PlayingGroup] {
        guard let trip = scorecardVM?.currentTrip,
              let round = trip.round(withId: roundId) else { return [] }
        return round.playingGroups
    }

    /// Returns true when the round has playing groups configured — surface a group selector.
    var hasPlayingGroups: Bool { !playingGroups.isEmpty }

    /// All players in the round, regardless of scope. Used by the picker UI to display the
    /// currently-mapped player even when scope has narrowed past them.
    var allRoundPlayers: [Player] {
        guard let trip = scorecardVM?.currentTrip,
              let round = trip.round(withId: roundId) else { return [] }
        return trip.players.filter { round.playerIds.contains($0.id) }
    }

    /// Switch the scope to a different playing group (or `nil` for all-players). Any rows
    /// currently mapped to a player outside the new scope are cleared so they don't silently
    /// apply to a hidden player.
    func setScopedGroup(_ groupId: UUID?) {
        scopedGroupId = groupId
        let visibleIds = Set(availablePlayers.map(\.id))
        playerByRow = playerByRow.filter { _, pid in visibleIds.contains(pid) }
    }

    /// True when this round has any existing scores — the apply step will confirm overwrite.
    var roundHasExistingScores: Bool {
        guard let trip = scorecardVM?.currentTrip,
              let round = trip.round(withId: roundId) else { return false }
        return round.scorecards.contains { $0.holesCompleted > 0 }
    }

    /// The trip players eligible to map to rows. Narrowed to the scoped playing group when
    /// one is selected, so a 12-player round doesn't surface all 12 in every picker.
    var availablePlayers: [Player] {
        guard let trip = scorecardVM?.currentTrip,
              let round = trip.round(withId: roundId) else { return [] }
        let inRound = trip.players.filter { round.playerIds.contains($0.id) }
        guard let groupId = scopedGroupId,
              let group = round.playingGroups.first(where: { $0.id == groupId }) else {
            return inRound
        }
        return inRound.filter { group.playerIds.contains($0.id) }
    }

    // MARK: - Pipeline

    func process(image: UIImage) async {
        self.image = image
        step = .parsing
        do {
            let observations = try await ScorecardOCRService.recognize(in: image)
            let result = ScorecardLayoutParser.parse(observations: observations, holeCount: holeCount)
            self.parsed = result
            guard result.headerDetected else {
                step = .noHeader
                return
            }
            preassignRowsFromCourseMemory()
            step = .review
        } catch {
            step = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Reset to the capture step (used for retake).
    func reset() {
        image = nil
        parsed = nil
        playerByRow = [:]
        overrides = [:]
        confirmedCells = []
        step = .capture
    }

    // MARK: - Row → player mapping

    /// Apply remembered row→player mapping for this course, if available.
    private func preassignRowsFromCourseMemory() {
        guard let trip = scorecardVM?.currentTrip,
              let course = trip.course(withId: courseId),
              let parsed else { return }

        let memory = course.preferredRowAssignments
        guard !memory.isEmpty else { return }

        for row in parsed.rows {
            // Find a player whose remembered rowIndex matches this row's index AND who's in this round.
            let match = memory.first { _, idx in idx == row.rowIndex }
            guard let (uuidString, _) = match,
                  let playerId = UUID(uuidString: uuidString),
                  availablePlayers.contains(where: { $0.id == playerId }),
                  !playerByRow.values.contains(playerId) else { continue }
            playerByRow[row.id] = playerId
        }
    }

    /// Toggle/set player assignment for a row.
    func assign(player playerId: UUID?, toRow rowId: UUID) {
        if let playerId {
            // Ensure one player isn't double-assigned: clear any other rows mapped to this player.
            for (otherRow, otherPlayer) in playerByRow where otherPlayer == playerId && otherRow != rowId {
                playerByRow.removeValue(forKey: otherRow)
            }
            playerByRow[rowId] = playerId
        } else {
            playerByRow.removeValue(forKey: rowId)
        }
    }

    // MARK: - Cell editing

    func cellKey(rowId: UUID, holeNumber: Int) -> String {
        "\(rowId.uuidString)#\(holeNumber)"
    }

    /// The strokes the user will commit for a cell (override if present, else OCR value, else nil).
    func effectiveStrokes(rowId: UUID, holeNumber: Int) -> Int? {
        let key = cellKey(rowId: rowId, holeNumber: holeNumber)
        if let override = overrides[key] { return override }
        return parsed?.rows.first(where: { $0.id == rowId })?
            .cells.first(where: { $0.holeNumber == holeNumber })?.strokes
    }

    func setOverride(rowId: UUID, holeNumber: Int, value: Int?) {
        let key = cellKey(rowId: rowId, holeNumber: holeNumber)
        if let value, value >= 1, value <= 15 {
            overrides[key] = value
            confirmedCells.insert(key)
        } else {
            overrides.removeValue(forKey: key)
        }
    }

    func confirm(rowId: UUID, holeNumber: Int) {
        confirmedCells.insert(cellKey(rowId: rowId, holeNumber: holeNumber))
    }

    /// True if a cell is flagged (low confidence OR sum-mismatch) AND the user hasn't confirmed it.
    func isCellFlagged(rowId: UUID, holeNumber: Int) -> Bool {
        let key = cellKey(rowId: rowId, holeNumber: holeNumber)
        if confirmedCells.contains(key) { return false }
        guard let cell = parsed?.rows.first(where: { $0.id == rowId })?
            .cells.first(where: { $0.holeNumber == holeNumber }) else { return false }
        return cell.flagged
    }

    // MARK: - Apply

    enum ApplyOutcome {
        case success(updatedHoles: Int)
        case noPlayersMapped
        case missingDependencies
    }

    /// Writes the imported scores into the round via `ScorecardViewModel.updateScore`.
    /// If every cell for every mapped player is filled, marks the round complete.
    @discardableResult
    func apply() -> ApplyOutcome {
        guard let scorecardVM,
              let parsed,
              let trip = scorecardVM.currentTrip,
              let round = trip.round(withId: roundId),
              let course = trip.course(withId: courseId) else {
            return .missingDependencies
        }
        guard !playerByRow.isEmpty else { return .noPlayersMapped }

        // Photo OCR doesn't extract putts. Mark each imported scorecard so consumers (challenges,
        // side games like Snake) know its zero-putt values aren't authoritative — without
        // affecting other players in the round who may have entered putts manually.
        var updatedHoles = 0
        for row in parsed.rows {
            guard let playerId = playerByRow[row.id] else { continue }
            // Flag this scorecard as putts-imported BEFORE writing scores.
            if let card = round.scorecards.first(where: { $0.player?.id == playerId }) {
                card.puttsImported = true
            }
            for hole in 1...holeCount {
                guard let strokes = effectiveStrokes(rowId: row.id, holeNumber: hole) else { continue }
                let didUpdate = scorecardVM.updateScore(
                    roundId: roundId,
                    playerId: playerId,
                    holeNumber: hole,
                    strokes: strokes,
                    putts: 0
                )
                if didUpdate { updatedHoles += 1 }
            }
        }

        // Persist row→player memory on the course for next import.
        var memory = course.preferredRowAssignments
        for (rowId, playerId) in playerByRow {
            guard let row = parsed.rows.first(where: { $0.id == rowId }) else { continue }
            memory[playerId.uuidString] = row.rowIndex
        }
        course.preferredRowAssignments = memory

        // Auto-complete the round only if every player in the round has every hole filled —
        // not just the ones mapped in this import. Marking the round complete with any player
        // sitting at 0 strokes corrupts handicap, match play, and side game results.
        if allRoundPlayersComplete(in: round) {
            scorecardVM.completeRound(round.id)
        }

        return .success(updatedHoles: updatedHoles)
    }

    private func allRoundPlayersComplete(in round: Round) -> Bool {
        guard !round.playerIds.isEmpty else { return false }
        for playerId in round.playerIds {
            guard let card = round.scorecard(forPlayer: playerId) else { return false }
            let scored = card.holeScores.filter { $0.strokes > 0 }.count
            if scored < holeCount { return false }
        }
        return true
    }
}

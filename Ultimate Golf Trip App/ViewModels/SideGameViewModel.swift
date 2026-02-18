import Foundation

@Observable
class SideGameViewModel {
    var appState: AppState

    var selectedGameType: SideGameType = .skins
    var selectedRoundId: UUID?
    var selectedParticipantIds: Set<UUID> = []
    var stakesAmount: String = ""
    var designatedHoles: Set<Int> = []
    var showingCreateGame = false

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? { appState.currentTrip }

    var activeSideGames: [SideGame] {
        currentTrip?.sideGames.filter { $0.isActive } ?? []
    }

    var completedSideGames: [SideGame] {
        currentTrip?.sideGames.filter { !$0.isActive } ?? []
    }

    // MARK: - Create Side Game

    func createSideGame() {
        guard let trip = currentTrip else { return }

        let stakes = Double(stakesAmount) ?? 0
        let round = selectedRoundId.flatMap { roundId in
            trip.rounds.first { $0.id == roundId }
        }
        let game = SideGame(
            type: selectedGameType,
            round: round,
            participantIds: Array(selectedParticipantIds),
            stakes: stakes,
            designatedHoles: Array(designatedHoles).sorted()
        )
        game.trip = trip
        trip.sideGames.append(game)
        appState.saveContext()
        resetForm()
    }

    // MARK: - Calculate Results

    func calculateResults(for gameId: UUID) {
        guard let trip = currentTrip,
              let game = trip.sideGames.first(where: { $0.id == gameId }),
              let round = game.round,
              let course = round.course else { return }

        let participantCards = round.scorecards.filter { card in
            guard let pid = card.player?.id else { return false }
            return game.participantIds.contains(pid)
        }

        // Process scorecards with handicap
        let processedRound = ScoringEngine.processRound(round: round, course: course)
        let processedCards = processedRound.scorecards.filter { card in
            game.participantIds.contains(card.playerId)
        }

        var results: [SideGameResult] = []

        switch game.type {
        case .skins:
            results = SideGameEngine.calculateSkins(
                scorecards: processedCards,
                stakes: game.stakes,
                holes: course.holes
            )
        case .nassau:
            results = SideGameEngine.calculateNassau(
                scorecards: processedCards,
                stakes: game.stakes
            )
        case .snake:
            results = SideGameEngine.calculateSnake(
                scorecards: participantCards,
                stakes: game.stakes
            )
        case .rabbit:
            results = SideGameEngine.calculateRabbit(
                scorecards: processedCards,
                stakes: game.stakes,
                holes: course.holes
            )
        default:
            break
        }

        game.results = results
        appState.saveContext()
    }

    // MARK: - Manual Result Entry

    func addManualResult(gameId: UUID, holeNumber: Int, winnerId: UUID, description: String) {
        guard let trip = currentTrip,
              let game = trip.sideGames.first(where: { $0.id == gameId }) else { return }

        let result = SideGameResult(
            holeNumber: holeNumber,
            winnerId: winnerId,
            amount: game.stakes,
            description: description
        )
        game.addResult(result)
        appState.saveContext()
    }

    // MARK: - Side Game Standings

    func standings(for gameId: UUID) -> [(playerId: UUID, playerName: String, amount: Double)] {
        guard let trip = currentTrip,
              let game = trip.sideGames.first(where: { $0.id == gameId }) else { return [] }

        return game.participantIds.compactMap { playerId in
            guard let player = trip.player(withId: playerId) else { return nil }
            let amount = game.totalWinnings(forPlayer: playerId)
            return (playerId: playerId, playerName: player.name, amount: amount)
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - End Side Game

    func endSideGame(_ gameId: UUID) {
        guard let trip = currentTrip,
              let game = trip.sideGames.first(where: { $0.id == gameId }) else { return }
        game.isActive = false
        appState.saveContext()
    }

    func deleteSideGame(_ gameId: UUID) {
        guard let trip = currentTrip else { return }
        trip.sideGames.removeAll { $0.id == gameId }
        appState.saveContext()
    }

    // MARK: - Form

    private func resetForm() {
        selectedGameType = .skins
        selectedRoundId = nil
        selectedParticipantIds = []
        stakesAmount = ""
        designatedHoles = []
        showingCreateGame = false
    }
}

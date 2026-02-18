import Foundation
import SwiftUI

@Observable
class TripViewModel {
    var appState: AppState

    // Trip creation
    var tripName: String = ""
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()

    // Player creation
    var newPlayerName: String = ""
    var newPlayerHandicap: String = ""
    var newPlayerColor: PlayerColor = .blue
    var newPlayerTeamId: UUID?

    // Course creation
    var newCourseName: String = ""
    var newCourseCity: String = ""
    var newCourseState: String = ""
    var newCourseSlopeRating: String = "113"
    var newCourseCourseRating: String = "72.0"

    // Team creation
    var newTeamName: String = ""
    var newTeamColor: TeamColor = .blue

    var showingAddPlayer = false
    var showingAddCourse = false
    var showingAddTeam = false
    var showingCreateTrip = false

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? {
        appState.currentTrip
    }

    var trips: [Trip] {
        appState.trips
    }

    // MARK: - Trip Management

    func createTrip() {
        let trip = Trip(
            name: tripName,
            startDate: startDate,
            endDate: endDate,
            ownerProfileId: appState.currentUser?.id
        )
        appState.addTrip(trip)

        // Auto-add the current user as the first player
        if let user = appState.currentUser {
            let player = Player(
                name: user.name,
                handicapIndex: user.handicapIndex,
                avatarColor: user.avatarColor,
                userProfileId: user.id
            )
            trip.addPlayer(player)
            appState.saveContext()
        }

        resetTripForm()

        Task {
            await appState.saveTripToCloud(trip)
        }
    }

    func selectTrip(_ trip: Trip) {
        appState.currentTrip = trip
    }

    func deleteTrip(_ trip: Trip) {
        appState.deleteTrip(id: trip.id)
    }

    func leaveTrip(_ trip: Trip) {
        guard let myPlayer = appState.myPlayer(in: trip) else { return }
        trip.removePlayer(id: myPlayer.id)
        appState.saveContext()

        // If we were viewing this trip, switch away
        if appState.currentTrip?.id == trip.id {
            appState.trips.removeAll { $0.id == trip.id }
            appState.currentTrip = appState.trips.first
        }
    }

    func joinTrip(shareCode: String) async throws {
        // CloudKit must be enabled to join trips by share code
        guard AppState.cloudKitEnabled else {
            throw JoinTripError.tripNotFound
        }

        guard let trip = try await CloudKitService.shared.fetchTripByShareCode(shareCode) else {
            throw JoinTripError.tripNotFound
        }

        // Check if user is already a player in this trip
        if let user = appState.currentUser,
           trip.players.contains(where: { $0.userProfileId == user.id }) {
            throw JoinTripError.alreadyJoined
        }

        // Insert trip locally
        await MainActor.run {
            appState.addTrip(trip)

            // Add current user as a player
            if let user = appState.currentUser {
                let player = Player(
                    name: user.name,
                    handicapIndex: user.handicapIndex,
                    avatarColor: user.avatarColor,
                    userProfileId: user.id
                )
                trip.addPlayer(player)
                appState.saveContext()
            }
        }

        // Explicitly push the joined trip to CloudKit (it might not be currentTrip when debounce fires)
        await appState.saveTripToCloud(trip)
    }

    // MARK: - Player Management

    func addPlayer() {
        guard !newPlayerName.isEmpty, let trip = currentTrip else { return }
        let handicap = Double(newPlayerHandicap) ?? 0.0

        // Find team object if teamId is set
        let team = newPlayerTeamId.flatMap { teamId in
            trip.teams.first { $0.id == teamId }
        }

        let player = Player(
            name: newPlayerName,
            handicapIndex: handicap,
            team: team,
            avatarColor: newPlayerColor
        )
        trip.addPlayer(player)
        appState.saveContext()
        resetPlayerForm()
    }

    func removePlayer(_ player: Player) {
        guard let trip = currentTrip else { return }
        trip.removePlayer(id: player.id)
        appState.saveContext()
    }

    func updatePlayerHandicap(_ player: Player, newHandicap: Double) {
        guard currentTrip != nil else { return }
        player.handicapIndex = newHandicap
        appState.saveContext()
    }

    func assignPlayerToTeam(_ player: Player, team: Team?) {
        guard currentTrip != nil else { return }
        player.team = team
        appState.saveContext()
    }

    // MARK: - Course Management

    func addCourse() {
        guard !newCourseName.isEmpty, let trip = currentTrip else { return }
        let course = Course(
            name: newCourseName,
            holes: Course.defaultEighteenHoles(),
            slopeRating: Double(newCourseSlopeRating) ?? 113,
            courseRating: Double(newCourseCourseRating) ?? 72.0,
            city: newCourseCity,
            state: newCourseState
        )
        course.trip = trip
        trip.courses.append(course)
        appState.saveContext()
        resetCourseForm()
    }

    func removeCourse(_ course: Course) {
        guard let trip = currentTrip else { return }
        trip.courses.removeAll { $0.id == course.id }
        appState.saveContext()
    }

    func updateCourseHole(_ course: Course, holeIndex: Int, par: Int, yardage: Int, handicapRating: Int) {
        guard currentTrip != nil,
              holeIndex < course.holes.count else { return }

        course.holes[holeIndex].par = par
        course.holes[holeIndex].yardage = yardage
        course.holes[holeIndex].handicapRating = handicapRating
        appState.saveContext()
    }

    // MARK: - Team Management

    func addTeam() {
        guard !newTeamName.isEmpty, let trip = currentTrip else { return }
        let team = Team(name: newTeamName, color: newTeamColor)
        team.trip = trip
        trip.teams.append(team)
        appState.saveContext()
        resetTeamForm()
    }

    func removeTeam(_ team: Team) {
        guard let trip = currentTrip else { return }
        // Unassign players from this team
        for player in trip.players {
            if player.team?.id == team.id {
                player.team = nil
            }
        }
        trip.teams.removeAll { $0.id == team.id }
        appState.saveContext()
    }

    // MARK: - Trip Rules

    func updateTripRules(pointsPerWin: Double, pointsPerHalve: Double, pointsPerLoss: Double) {
        guard let trip = currentTrip else { return }
        trip.pointsPerMatchWin = pointsPerWin
        trip.pointsPerMatchHalve = pointsPerHalve
        trip.pointsPerMatchLoss = pointsPerLoss
        appState.saveContext()
    }

    func updateCourseScoringRule(_ course: Course, rule: TeamScoringRule?) {
        course.teamScoringRule = rule
        appState.saveContext()
    }

    // MARK: - Form Reset

    private func resetTripForm() {
        tripName = ""
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    }

    private func resetPlayerForm() {
        newPlayerName = ""
        newPlayerHandicap = ""
        newPlayerColor = PlayerColor.allCases.randomElement() ?? .blue
        newPlayerTeamId = nil
        showingAddPlayer = false
    }

    private func resetCourseForm() {
        newCourseName = ""
        newCourseCity = ""
        newCourseState = ""
        newCourseSlopeRating = "113"
        newCourseCourseRating = "72.0"
        showingAddCourse = false
    }

    private func resetTeamForm() {
        newTeamName = ""
        newTeamColor = TeamColor.allCases.randomElement() ?? .blue
        showingAddTeam = false
    }
}

// MARK: - Join Trip Errors

enum JoinTripError: LocalizedError {
    case tripNotFound
    case alreadyJoined

    var errorDescription: String? {
        switch self {
        case .tripNotFound:
            return "No trip found with that share code. Check the code and try again."
        case .alreadyJoined:
            return "You've already joined this trip."
        }
    }
}

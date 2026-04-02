import Foundation
import SwiftUI

@MainActor @Observable
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
    var newCourseLatitude: Double?
    var newCourseLongitude: Double?
    /// Matched course data from bundled database (set by search service)
    var matchedCourseData: CourseData?
    /// Available tee boxes for the matched course (generated from database)
    var availableTeeBoxes: [TeeBox] = []
    /// Selected tee box name during course creation
    var selectedTeeBoxName: String?

    // Course editing
    var showingEditCourse = false
    var editingCourse: Course?

    // Team creation / editing
    var newTeamName: String = ""
    var newTeamColor: TeamColor = .blue
    var showingEditTeam = false
    var editingTeam: Team?

    // Trip editing
    var showingEditTrip = false
    var editTripName: String = ""
    var editTripStartDate: Date = Date()
    var editTripEndDate: Date = Date()

    // Player editing
    var showingEditPlayer = false
    var editingPlayer: Player?
    var editPlayerName: String = ""
    var editPlayerHandicap: String = ""
    var editPlayerColor: PlayerColor = .blue
    var editPlayerTeamId: UUID?

    // Team editing
    var editTeamName: String = ""
    var editTeamColor: TeamColor = .blue

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
        let trimmedName = tripName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let trip = Trip(
            name: trimmedName,
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
            await appState.subscribeToTrip(trip)
        }
    }

    func selectTrip(_ trip: Trip) {
        appState.currentTrip = trip
    }

    func deleteTrip(_ trip: Trip) {
        appState.deleteTrip(id: trip.id)
    }

    /// Error message shown when leaving a trip fails.
    var leaveTripError: String?

    func leaveTrip(_ trip: Trip) {
        guard let myPlayer = appState.myPlayer(in: trip) else { return }
        let tripId = trip.id
        let playerId = myPlayer.id
        trip.removePlayer(id: playerId)

        Task {
            // Step 1: Push updated trip (player removed) to cloud
            await appState.saveTripToCloud(trip)

            // Step 2: Check if the push succeeded before deleting locally
            if appState.lastSyncFailed {
                // Cloud push failed — re-add the player locally to keep data consistent
                await MainActor.run {
                    if let player = Player(id: playerId, name: myPlayer.name, handicapIndex: myPlayer.handicapIndex, avatarColor: myPlayer.avatarColor, userProfileId: myPlayer.userProfileId) as Player? {
                        trip.addPlayer(player)
                        appState.saveContext()
                    }
                    leaveTripError = appState.lastSyncError ?? "Could not leave trip — check your connection and try again."
                }
                return
            }

            // Step 3: Unsubscribe from push notifications
            do {
                try await CloudKitService.shared.unsubscribeFromTripChanges(tripId: tripId)
            } catch {
                print("⚠️ Failed to unsubscribe from trip \(tripId): \(error.localizedDescription)")
            }

            // Step 4: Delete locally only after cloud push succeeded
            await MainActor.run {
                appState.deleteTrip(id: tripId)
            }
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

        // Check if user is already a linked player in this trip
        if let user = appState.currentUser,
           trip.players.contains(where: { $0.userProfileId == user.id }) {
            throw JoinTripError.alreadyJoined
        }

        // Insert trip locally
        await MainActor.run {
            appState.addTrip(trip)

            if let user = appState.currentUser {
                // Check if a manually-created player with the same name already exists.
                // If so, link it to this user instead of creating a duplicate.
                let normalizedName = user.name.trimmingCharacters(in: .whitespaces).lowercased()
                if let existingPlayer = trip.players.first(where: {
                    $0.userProfileId == nil &&
                    $0.name.trimmingCharacters(in: .whitespaces).lowercased() == normalizedName
                }) {
                    existingPlayer.userProfileId = user.id
                    existingPlayer.handicapIndex = user.handicapIndex
                    existingPlayer.avatarColor = user.avatarColor
                } else {
                    // No matching player — create a new one
                    let player = Player(
                        name: user.name,
                        handicapIndex: user.handicapIndex,
                        avatarColor: user.avatarColor,
                        userProfileId: user.id
                    )
                    trip.addPlayer(player)
                }
                appState.saveContext()
            }
        }

        // Push the joined trip to CloudKit and subscribe to future changes
        await appState.saveTripToCloud(trip)
        await appState.subscribeToTrip(trip)
    }

    // MARK: - Trip Editing

    func startEditingTrip() {
        guard let trip = currentTrip else { return }
        editTripName = trip.name
        editTripStartDate = trip.startDate
        editTripEndDate = trip.endDate
        showingEditTrip = true
    }

    func saveTripEdits() {
        guard let trip = currentTrip else { return }
        let trimmedName = editTripName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        trip.name = trimmedName
        trip.startDate = editTripStartDate
        trip.endDate = editTripEndDate
        appState.saveContext()
        resetEditTripForm()
    }

    private func resetEditTripForm() {
        editTripName = ""
        editTripStartDate = Date()
        editTripEndDate = Date()
        showingEditTrip = false
    }

    // MARK: - Player Management

    func addPlayer() {
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let trip = currentTrip else { return }
        // Prevent duplicate player names (case-insensitive)
        let normalizedName = trimmedName.lowercased()
        guard !trip.players.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).lowercased() == normalizedName }) else { return }
        newPlayerName = trimmedName
        let handicap = min(54.0, max(-10.0, Double(newPlayerHandicap) ?? 0.0))

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

    /// Prepare the edit form for an existing player
    func startEditingPlayer(_ player: Player) {
        editingPlayer = player
        editPlayerName = player.name
        editPlayerHandicap = player.handicapIndex == 0 ? "" : String(format: "%.1f", player.handicapIndex)
        editPlayerColor = player.avatarColor
        editPlayerTeamId = player.teamId
        showingEditPlayer = true
    }

    /// Save edits to an existing player
    func savePlayerEdits() {
        guard let player = editingPlayer else { return }
        player.name = editPlayerName.trimmingCharacters(in: .whitespaces)
        player.handicapIndex = min(54.0, max(-10.0, Double(editPlayerHandicap) ?? 0.0))
        player.avatarColor = editPlayerColor

        // Update team assignment
        if let teamId = editPlayerTeamId {
            player.team = currentTrip?.teams.first { $0.id == teamId }
        } else {
            player.team = nil
        }

        appState.saveContext()
        resetEditPlayerForm()
    }

    private func resetEditPlayerForm() {
        editingPlayer = nil
        editPlayerName = ""
        editPlayerHandicap = ""
        editPlayerColor = .blue
        editPlayerTeamId = nil
        showingEditPlayer = false
    }

    // MARK: - Course Management

    func addCourse() {
        guard !newCourseName.isEmpty, let trip = currentTrip else { return }

        // Use matched course data for holes if available, otherwise defaults
        let holes: [Hole]
        var teeBoxes: [TeeBox] = []
        if let data = matchedCourseData {
            holes = data.holes.map { holeData in
                Hole(
                    number: holeData.number,
                    par: holeData.par,
                    yardage: holeData.yardage,
                    handicapRating: holeData.handicapRating
                )
            }
            // Generate tee boxes from the matched database course
            teeBoxes = GolfCourseDatabase.shared.teeBoxes(for: data)
        } else {
            holes = Course.defaultEighteenHoles()
        }

        let course = Course(
            name: newCourseName,
            holes: holes,
            slopeRating: Double(newCourseSlopeRating) ?? 113,
            courseRating: Double(newCourseCourseRating) ?? 72.0,
            city: newCourseCity,
            state: newCourseState,
            latitude: newCourseLatitude,
            longitude: newCourseLongitude,
            teeBoxes: teeBoxes,
            selectedTeeBoxName: selectedTeeBoxName
        )
        course.trip = trip
        trip.courses.append(course)
        appState.saveContext()
        resetCourseForm()
    }

    func removeCourse(_ course: Course) {
        guard let trip = currentTrip else { return }
        if !trip.deletedCourseIds.contains(course.id.uuidString) {
            trip.deletedCourseIds.append(course.id.uuidString)
        }
        trip.courses.removeAll { $0.id == course.id }
        Task { await CloudKitService.shared.deleteRecord(id: course.id) }
        appState.saveContext()
    }

    /// Update an existing course's properties
    func updateCourse(_ course: Course, name: String, slopeRating: Double, courseRating: Double, holes: [Hole], teeBoxes: [TeeBox], selectedTeeBoxName: String?) {
        guard currentTrip != nil else { return }
        course.name = name
        course.slopeRating = slopeRating
        course.courseRating = courseRating
        course.holes = holes
        course.teeBoxes = teeBoxes
        course.selectedTeeBoxName = selectedTeeBoxName
        appState.saveContext()
    }

    /// Apply a tee box to an existing course (updates slope, rating, and yardages)
    func applyTeeBox(_ teeBox: TeeBox, to course: Course) {
        guard currentTrip != nil else { return }
        course.applyTeeBox(teeBox)
        appState.saveContext()
    }

    /// Prepare the edit form for an existing course
    func startEditingCourse(_ course: Course) {
        editingCourse = course
        newCourseName = course.name
        newCourseCity = course.city
        newCourseState = course.state
        newCourseSlopeRating = String(format: "%.0f", course.slopeRating)
        newCourseCourseRating = String(format: "%.1f", course.courseRating)
        newCourseLatitude = course.latitude
        newCourseLongitude = course.longitude
        availableTeeBoxes = course.teeBoxes
        selectedTeeBoxName = course.selectedTeeBoxName
        showingEditCourse = true
    }

    func updateCourseHole(_ course: Course, holeIndex: Int, par: Int, yardage: Int, handicapRating: Int) {
        guard currentTrip != nil,
              holeIndex >= 0, holeIndex < course.holes.count else { return }

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
        if !trip.deletedTeamIds.contains(team.id.uuidString) {
            trip.deletedTeamIds.append(team.id.uuidString)
        }
        // Unassign players from this team
        for player in trip.players {
            if player.team?.id == team.id {
                player.team = nil
            }
        }
        trip.teams.removeAll { $0.id == team.id }
        Task { await CloudKitService.shared.deleteRecord(id: team.id) }
        appState.saveContext()
    }

    /// Prepare the edit form for an existing team
    func startEditingTeam(_ team: Team) {
        editingTeam = team
        editTeamName = team.name
        editTeamColor = team.color
        showingEditTeam = true
    }

    /// Save edits to an existing team
    func saveTeamEdits() {
        guard let team = editingTeam else { return }
        team.name = editTeamName.trimmingCharacters(in: .whitespaces)
        team.color = editTeamColor
        appState.saveContext()
        resetEditTeamForm()
    }

    private func resetEditTeamForm() {
        editingTeam = nil
        editTeamName = ""
        editTeamColor = .blue
        showingEditTeam = false
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
        newCourseLatitude = nil
        newCourseLongitude = nil
        matchedCourseData = nil
        availableTeeBoxes = []
        selectedTeeBoxName = nil
        editingCourse = nil
        showingAddCourse = false
        showingEditCourse = false
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

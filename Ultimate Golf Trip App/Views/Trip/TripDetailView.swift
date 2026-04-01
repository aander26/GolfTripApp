import SwiftUI

struct TripDetailView: View {
    @Bindable var viewModel: TripViewModel
    @Environment(AppState.self) private var appState
    @State private var showingEditProfile = false
    @State private var showingLeaveConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if let trip = viewModel.currentTrip {
                    // Trip Info
                    Section("Trip Info") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trip.name)
                                    .font(.headline)
                                Text(trip.dateRange)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.startEditingTrip()
                        }
                        .accessibilityLabel("Trip \(trip.name), \(trip.dateRange), tap to edit")

                        LabeledContent("Share Code", value: trip.shareCode)
                            .contextMenu {
                                Button("Copy Code") {
                                    UIPasteboard.general.string = trip.shareCode
                                }
                            }
                        LabeledContent("Rounds", value: "\(trip.completedRounds.count) / \(trip.rounds.count)")
                    }

                    // Players Section
                    Section {
                        ForEach(trip.players) { player in
                            PlayerRowView(player: player, team: trip.team(withId: player.teamId ?? UUID()))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.startEditingPlayer(player)
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet.sorted().reversed() {
                                viewModel.removePlayer(trip.players[index])
                            }
                        }

                        Button {
                            viewModel.showingAddPlayer = true
                        } label: {
                            Label("Add Player", systemImage: "person.badge.plus")
                        }
                    } header: {
                        Text("Players (\(trip.players.count))")
                    }

                    // Teams Section
                    Section {
                        ForEach(trip.teams) { team in
                            TeamRowView(
                                team: team,
                                players: trip.playersOnTeam(team.id)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.startEditingTeam(team)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet.sorted().reversed() {
                                viewModel.removeTeam(trip.teams[index])
                            }
                        }

                        if !trip.teams.isEmpty {
                            NavigationLink {
                                TeamAssignmentView(viewModel: viewModel)
                            } label: {
                                Label("Assign Players to Teams", systemImage: "arrow.left.arrow.right")
                            }
                        }

                        Button {
                            viewModel.showingAddTeam = true
                        } label: {
                            Label("Add Team", systemImage: "person.3.fill")
                        }
                    } header: {
                        Text("Teams (\(trip.teams.count))")
                    }

                    // Trip Rules (only show when teams exist)
                    if trip.teams.count >= 2 {
                        Section {
                            NavigationLink {
                                TripRulesView(viewModel: viewModel)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Label("Team Competition Rules", systemImage: "trophy.fill")
                                        Spacer()
                                    }
                                    let coursesWithRules = trip.courses.filter { $0.teamScoringRule != nil }.count
                                    if coursesWithRules > 0 {
                                        Text("\(coursesWithRules) course\(coursesWithRules == 1 ? "" : "s") with custom rules")
                                            .font(.caption)
                                            .foregroundStyle(Theme.primary)
                                    } else {
                                        Text("Default: Match Play \u{00B7} W:\(trip.pointsPerMatchWin, specifier: "%.1f") H:\(trip.pointsPerMatchHalve, specifier: "%.1f") L:\(trip.pointsPerMatchLoss, specifier: "%.1f")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Trip Rules")
                        }
                    }

                    // Courses Section
                    Section {
                        ForEach(trip.courses) { course in
                            CourseRowView(course: course)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.startEditingCourse(course)
                                }
                        }
                        .onDelete { indexSet in
                            for index in indexSet.sorted().reversed() {
                                viewModel.removeCourse(trip.courses[index])
                            }
                        }

                        Button {
                            viewModel.showingAddCourse = true
                        } label: {
                            Label("Add Course", systemImage: "flag.fill")
                        }
                    } header: {
                        Text("Courses (\(trip.courses.count))")
                    }

                    // Rounds Section
                    Section("Rounds") {
                        if trip.rounds.isEmpty {
                            Text("No rounds yet. Start one from the Scorecard tab.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(trip.rounds) { round in
                                RoundRowView(
                                    round: round,
                                    courseName: round.course?.name ?? "Unknown"
                                )
                            }
                        }
                    }

                    // Profile & Trip Actions
                    Section {
                        Button {
                            showingEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "person.circle")
                        }

                        Button("Switch Trip") {
                            appState.currentTrip = nil
                        }

                        if !trip.isOwner(appState.currentUser?.id) {
                            Button(role: .destructive) {
                                showingLeaveConfirmation = true
                            } label: {
                                Label("Leave Trip", systemImage: "arrow.right.square")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No Trip Selected",
                        systemImage: "flag.fill",
                        description: Text("Create or select a trip to get started")
                    )
                }
            }
            .themedList()
            .navigationTitle(viewModel.currentTrip?.name ?? "Trip")
            .sheet(isPresented: $viewModel.showingEditTrip) {
                EditTripSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddPlayer) {
                AddPlayerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddTeam) {
                AddTeamSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddCourse) {
                AddCourseSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditCourse) {
                EditCourseSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditPlayer) {
                EditPlayerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEditTeam) {
                EditTeamSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
            }
            .confirmationDialog("Leave Trip", isPresented: $showingLeaveConfirmation, titleVisibility: .visible) {
                Button("Leave Trip", role: .destructive) {
                    if let trip = viewModel.currentTrip {
                        viewModel.leaveTrip(trip)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to leave this trip? You will need a share code to rejoin.")
            }
        }
    }
}

// MARK: - Row Views

struct PlayerRowView: View {
    let player: Player
    let team: Team?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(player.avatarColor.color)
                .frame(width: 36, height: 36)
                .overlay {
                    Text(player.initials)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(.body)
                HStack(spacing: 8) {
                    Text("HCP: \(player.formattedHandicap)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let team = team {
                        Text(team.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(team.color.color.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.name), handicap \(player.formattedHandicap)\(team.map { ", team \($0.name)" } ?? ""), tap to edit")
    }
}

struct TeamRowView: View {
    let team: Team
    let players: [Player]

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(team.color.color)
                        .frame(width: 12, height: 12)
                        .accessibilityHidden(true)
                    Text(team.name)
                        .font(.headline)
                }
                if players.isEmpty {
                    Text("No players assigned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(players.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Team \(team.name), \(players.isEmpty ? "no players assigned" : players.map(\.name).joined(separator: ", ")), tap to edit")
    }
}

struct CourseRowView: View {
    let course: Course

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(course.name)
                    .font(.body)
                HStack(spacing: 12) {
                    Text("Par \(course.totalPar)")
                    Text("\(course.totalYardage) yds")
                    Text("Slope: \(Int(course.slopeRating))")
                    if !course.location.isEmpty {
                        Text(course.location)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    if let teeName = course.selectedTeeBoxName {
                        Text("\(teeName) Tees")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    if let rule = course.teamScoringRule {
                        Text(rule.summaryText)
                            .font(.caption2)
                            .foregroundStyle(Theme.primary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

struct RoundRowView: View {
    let round: Round
    let courseName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(courseName)
                    .font(.body)
                Spacer()
                if round.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("In Progress")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            HStack(spacing: 12) {
                Text(round.formattedDate)
                Text(round.format.rawValue)
                Text("\(round.playerIds.count) players")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(courseName), \(round.formattedDate), \(round.format.rawValue), \(round.playerIds.count) players, \(round.isComplete ? "completed" : "in progress")")
    }
}

#Preview {
    TripDetailView(viewModel: SampleData.makeTripViewModel())
        .environment(SampleData.makeAppState())
}

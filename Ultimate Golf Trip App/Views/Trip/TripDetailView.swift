import SwiftUI

struct TripDetailView: View {
    @Bindable var viewModel: TripViewModel
    @Environment(AppState.self) private var appState
    @State private var showingEditProfile = false

    var body: some View {
        NavigationStack {
            List {
                if let trip = viewModel.currentTrip {
                    // Trip Info
                    Section("Trip Info") {
                        LabeledContent("Dates", value: trip.dateRange)
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
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
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
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
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
                    if trip.teams.count == 2 {
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
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
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
                                viewModel.leaveTrip(trip)
                            } label: {
                                Label("Leave Trip", systemImage: "arrow.right.square")
                            }
                        }
                    }
                }
            }
            .navigationTitle(viewModel.currentTrip?.name ?? "Trip")
            .sheet(isPresented: $viewModel.showingAddPlayer) {
                AddPlayerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddTeam) {
                AddTeamSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingAddCourse) {
                AddCourseSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(player.name), handicap \(player.formattedHandicap)\(team != nil ? ", team \(team!.name)" : "")")
    }
}

struct TeamRowView: View {
    let team: Team
    let players: [Player]

    var body: some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Team \(team.name), \(players.isEmpty ? "no players assigned" : players.map(\.name).joined(separator: ", "))")
    }
}

struct CourseRowView: View {
    let course: Course

    var body: some View {
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

            if let rule = course.teamScoringRule {
                Text(rule.summaryText)
                    .font(.caption2)
                    .foregroundStyle(Theme.primary)
            }
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

import SwiftUI

struct RoundSetupView: View {
    @Bindable var viewModel: ScorecardViewModel
    @Environment(\.dismiss) private var dismiss

    /// True when the trip is missing the bare minimum to play: no course, no players, or
    /// the current user isn't in the trip. The Quick Setup button bridges this gap so
    /// first-time users don't have to tab-switch back to Trip just to add a course.
    private var needsQuickSetup: Bool {
        guard let trip = viewModel.currentTrip else { return false }
        return trip.courses.isEmpty || trip.players.isEmpty
    }

    /// True when the selected format requires teams but the trip has none yet.
    /// Blocks the Start button so users don't end up in a broken match-play round.
    private var teamFormatMissingTeams: Bool {
        guard let trip = viewModel.currentTrip else { return false }
        return viewModel.selectedFormat.requiresTeams && trip.teams.isEmpty
    }

    /// Aggregated guard for the Start button — must satisfy course, players, and (if team format) teams.
    private var canStartRound: Bool {
        viewModel.selectedCourseId != nil &&
            !viewModel.selectedPlayerIds.isEmpty &&
            !teamFormatMissingTeams
    }

    var body: some View {
        NavigationStack {
            Form {
                if let trip = viewModel.currentTrip {
                    // Quick Setup — surfaces when the trip is missing a course or any player so
                    // first-time users can start a round without bouncing back to the Trip tab.
                    if needsQuickSetup {
                        Section {
                            Button {
                                runQuickSetup(trip: trip)
                            } label: {
                                Label("Quick Setup", systemImage: "wand.and.stars")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(BoldPrimaryButtonStyle())
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        } footer: {
                            Text(quickSetupFooterText(trip: trip))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Course Selection
                    Section("Course") {
                        if trip.courses.isEmpty {
                            Text("No courses yet. Tap “Quick Setup” above to add a default 18-hole course, or add one in the Trip tab.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Select Course", selection: $viewModel.selectedCourseId) {
                                Text("Select a course").tag(UUID?.none)
                                ForEach(trip.courses) { course in
                                    Text("\(course.name) (Par \(course.totalPar))")
                                        .tag(Optional(course.id))
                                }
                            }
                        }
                    }

                    // Format Selection
                    Section("Format") {
                        Picker("Scoring Format", selection: $viewModel.selectedFormat) {
                            ForEach(ScoringFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        Text(viewModel.selectedFormat.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // Block team-format rounds when no teams exist: silent failure mode used
                        // to let users start match play with 0 teams, breaking the live banner
                        // and downstream standings.
                        if teamFormatMissingTeams {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Theme.warning)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(viewModel.selectedFormat.rawValue) needs teams")
                                        .font(.caption.weight(.semibold))
                                    Text("Add at least two teams in the Trip tab, or pick Stroke Play / Stableford to keep playing as individuals.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Putts Tracking
                    Section {
                        Toggle("Track Putts", isOn: $viewModel.trackPuttsForSetup)
                        Text("When off, putts are hidden from the scorecard. Challenges that need putts data will still require entry.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Putts")
                    }

                    // Team Scoring Options (shown for team-based formats when teams exist)
                    if viewModel.selectedFormat.requiresTeams && !trip.teams.isEmpty {
                        Section {
                            Picker("Team Scoring", selection: $viewModel.selectedTeamScoringFormat) {
                                ForEach(TeamScoringFormat.allCases) { format in
                                    Text(format.shortName).tag(format)
                                }
                            }
                            .pickerStyle(.navigationLink)

                            Text(viewModel.selectedTeamScoringFormat.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("Team Competition")
                        }

                        // Points Configuration
                        if viewModel.selectedTeamScoringFormat == .ninesAndOverall {
                            Section("Points (Nines & Overall)") {
                                ninesPointsFields
                                Text("Each 1v1 match scores front 9, back 9, and overall separately. Max 5 pts per match.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Section("Scoring Structure") {
                                Picker("Points Structure", selection: $viewModel.teamUseNinesAndOverall) {
                                    Text("Per Match").tag(false)
                                    Text("Front 9 / Back 9 / Overall").tag(true)
                                }
                                .pickerStyle(.segmented)
                            }

                            if viewModel.teamUseNinesAndOverall {
                                Section("Points (Front 9 / Back 9 / Overall)") {
                                    ninesPointsFields
                                    Text("Points awarded for winning each segment: front 9, back 9, and overall 18.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Section("Points") {
                                    HStack {
                                        Text(viewModel.selectedTeamScoringFormat.pointsLabel + " (Win)")
                                        Spacer()
                                        TextField("1.0", text: $viewModel.teamPointsPerWin)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                    }
                                    HStack {
                                        Text("Halve")
                                        Spacer()
                                        TextField("0.5", text: $viewModel.teamPointsPerHalve)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                    }
                                    HStack {
                                        Text("Loss")
                                        Spacer()
                                        TextField("0.0", text: $viewModel.teamPointsPerLoss)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                    }
                                }
                            }
                        }
                    }

                    // Player Selection
                    Section("Players") {
                        if trip.players.isEmpty {
                            Text("No players yet. Tap “Quick Setup” to add yourself, or add players in the Trip tab.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(trip.players) { player in
                                HStack {
                                    Circle()
                                        .fill(player.avatarColor.color)
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            Text(player.initials)
                                                .font(.system(size: 10))
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }

                                    Text(player.name)

                                    Spacer()

                                    Text(player.formattedHandicap)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: viewModel.selectedPlayerIds.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.selectedPlayerIds.contains(player.id) ? Theme.primary : Theme.textSecondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.selectedPlayerIds.contains(player.id) {
                                        viewModel.selectedPlayerIds.remove(player.id)
                                    } else {
                                        viewModel.selectedPlayerIds.insert(player.id)
                                    }
                                }
                            }
                        }
                    }

                    // Match Pairings editor — only for match-play-flavored formats with teams.
                    let showsPairings = viewModel.selectedFormat == .matchPlay &&
                        !trip.teams.isEmpty &&
                        viewModel.selectedPlayerIds.count >= 2
                    if showsPairings {
                        Section {
                            matchPairingsSection(trip: trip)
                        } header: {
                            HStack {
                                Text("Match Pairings")
                                Spacer()
                                if !viewModel.matchPairingsForSetup.isEmpty {
                                    Button("Auto-pair") {
                                        viewModel.matchPairingsForSetup = autoGeneratePairings(trip: trip)
                                    }
                                    .font(.caption)
                                    .textCase(nil)
                                }
                            }
                        } footer: {
                            Text("Pair players from opposing teams. Leave blank to auto-pair by team roster order at round start.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Playing Groups (foursomes) — optional, surfaces when 5+ players selected
                    // since fewer than that doesn't need grouping.
                    if viewModel.selectedPlayerIds.count >= 5 {
                        Section {
                            playingGroupsSection(trip: trip)
                        } header: {
                            HStack {
                                Text("Playing Groups")
                                Spacer()
                                if !viewModel.playingGroupsForSetup.isEmpty {
                                    Button("Clear") { viewModel.playingGroupsForSetup = [] }
                                        .font(.caption)
                                        .textCase(nil)
                                }
                            }
                        } footer: {
                            Text("Optional. Split into foursomes if multiple groups will play at once — used to filter score entry and scope side games to a single on-course group.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Course Handicap Preview
                    if viewModel.selectedCourseId != nil && !viewModel.selectedPlayerIds.isEmpty {
                        Section("Course Handicaps") {
                            ForEach(trip.players.filter({ viewModel.selectedPlayerIds.contains($0.id) })) { player in
                                if let course = viewModel.selectedCourse {
                                    let ch = HandicapEngine.courseHandicap(
                                        handicapIndex: player.handicapIndex,
                                        slopeRating: course.slopeRating,
                                        courseRating: course.courseRating,
                                        par: course.totalPar
                                    )
                                    HStack {
                                        Text(player.name)
                                        Spacer()
                                        Text("Index: \(player.formattedHandicap)")
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Text("Course: \(ch)")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetRoundSetup()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        viewModel.startNewRound()
                        dismiss()
                    }
                    .disabled(!canStartRound)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Subviews

extension RoundSetupView {

    // MARK: - Quick setup

    /// Add a default 18-hole course and the current user as a player so a first-time user can
    /// start scoring immediately without bouncing back to the Trip tab. Idempotent — only
    /// creates entities that don't already exist.
    fileprivate func runQuickSetup(trip: Trip) {
        let appState = viewModel.appState
        var addedCourseId: UUID?
        var addedPlayerId: UUID?

        if trip.courses.isEmpty {
            let course = Course(
                name: "My Course",
                holes: Course.defaultEighteenHoles()
            )
            course.trip = trip
            trip.courses.append(course)
            addedCourseId = course.id
        }

        if trip.players.isEmpty {
            let profile = appState.currentUser
            let player = Player(
                name: profile?.name ?? "Me",
                handicapIndex: profile?.handicapIndex ?? 0,
                avatarColor: profile?.avatarColor ?? .blue,
                userProfileId: profile?.id
            )
            player.trip = trip
            trip.players.append(player)
            addedPlayerId = player.id
        }

        appState.saveContext()

        // Pre-select what we just created so Start is one tap away.
        if let cid = addedCourseId ?? trip.courses.first?.id {
            viewModel.selectedCourseId = cid
        }
        if let pid = addedPlayerId ?? trip.players.first?.id {
            viewModel.selectedPlayerIds.insert(pid)
        }
    }

    fileprivate func quickSetupFooterText(trip: Trip) -> String {
        switch (trip.courses.isEmpty, trip.players.isEmpty) {
        case (true, true):
            return "Adds a default 18-hole course and yourself as a player. You can rename or edit either later from the Trip tab."
        case (true, false):
            return "Adds a default 18-hole course. Rename or edit later from the Trip tab."
        case (false, true):
            return "Adds you to the roster so you can start playing right away."
        default:
            return ""
        }
    }


    @ViewBuilder
    func matchPairingsSection(trip: Trip) -> some View {
        let selectedPlayers = trip.players.filter { viewModel.selectedPlayerIds.contains($0.id) }
        if viewModel.matchPairingsForSetup.isEmpty {
            Button {
                viewModel.matchPairingsForSetup = autoGeneratePairings(trip: trip)
            } label: {
                Label("Generate pairings", systemImage: "person.2.fill")
            }
        } else {
            ForEach($viewModel.matchPairingsForSetup) { $pairing in
                matchPairingRow(pairing: $pairing, players: selectedPlayers, teams: trip.teams)
            }
            Button(role: .destructive) {
                viewModel.matchPairingsForSetup = []
            } label: {
                Label("Clear pairings", systemImage: "trash")
                    .font(.caption)
            }
        }
    }

    fileprivate func autoGeneratePairings(trip: Trip) -> [MatchPairing] {
        guard trip.teams.count >= 2 else { return [] }
        let selectedIds = viewModel.selectedPlayerIds
        var pairings: [MatchPairing] = []
        let teamPairs = TeamMatchPlayEngine.generateTeamPairs(teams: trip.teams)
        for (teamA, teamB) in teamPairs {
            let aPlayers = trip.players.filter { $0.team?.id == teamA.id && selectedIds.contains($0.id) }
            let bPlayers = trip.players.filter { $0.team?.id == teamB.id && selectedIds.contains($0.id) }
            pairings.append(contentsOf: TeamMatchPlayEngine.generatePairings(team1Players: aPlayers, team2Players: bPlayers))
        }
        return pairings
    }

    @ViewBuilder
    fileprivate func matchPairingRow(
        pairing: Binding<MatchPairing>,
        players: [Player],
        teams: [Team]
    ) -> some View {
        HStack(spacing: 8) {
            playerPickerForPairing(selection: pairing.player1Id, candidates: players, teams: teams)
            Text("vs")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.textSecondary)
            playerPickerForPairing(selection: pairing.player2Id, candidates: players, teams: teams)
        }
    }

    fileprivate func playerPickerForPairing(
        selection: Binding<UUID>,
        candidates: [Player],
        teams: [Team]
    ) -> some View {
        Menu {
            ForEach(teams, id: \.id) { team in
                let teamPlayers = candidates.filter { $0.team?.id == team.id }
                if !teamPlayers.isEmpty {
                    Section(team.name) {
                        ForEach(teamPlayers) { p in
                            Button(p.name) { selection.wrappedValue = p.id }
                        }
                    }
                }
            }
            // Players not on a team (or whose team isn't shown above)
            let unteamed = candidates.filter { p in
                guard let tid = p.team?.id else { return true }
                return !teams.contains(where: { $0.id == tid })
            }
            if !unteamed.isEmpty {
                Section("Other") {
                    ForEach(unteamed) { p in
                        Button(p.name) { selection.wrappedValue = p.id }
                    }
                }
            }
        } label: {
            let player = candidates.first { $0.id == selection.wrappedValue }
            HStack(spacing: 6) {
                if let player {
                    Circle()
                        .fill(player.avatarColor.color)
                        .frame(width: 18, height: 18)
                    Text(player.name).font(.caption.weight(.semibold)).lineLimit(1)
                } else {
                    Text("Pick player").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border, lineWidth: 1))
        }
    }

    @ViewBuilder
    func playingGroupsSection(trip: Trip) -> some View {
        let selectedPlayers = trip.players.filter { viewModel.selectedPlayerIds.contains($0.id) }

        if viewModel.playingGroupsForSetup.isEmpty {
            Button {
                viewModel.playingGroupsForSetup = autoSuggestGroups(for: selectedPlayers)
            } label: {
                Label("Auto-split into foursomes", systemImage: "person.3.fill")
            }
            Text("\(selectedPlayers.count) players → \((selectedPlayers.count + 3) / 4) groups of up to 4.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach($viewModel.playingGroupsForSetup) { $group in
                playingGroupRow(group: $group, allPlayers: selectedPlayers)
            }
            Button {
                viewModel.playingGroupsForSetup = autoSuggestGroups(for: selectedPlayers)
            } label: {
                Label("Reset groups", systemImage: "arrow.counterclockwise")
                    .font(.caption)
            }
        }
    }

    /// Suggest groups of 4 in roster order. Leftovers go into the final smaller group.
    fileprivate func autoSuggestGroups(for players: [Player]) -> [PlayingGroup] {
        let chunkSize = 4
        var groups: [PlayingGroup] = []
        var index = 1
        for chunk in stride(from: 0, to: players.count, by: chunkSize) {
            let end = min(chunk + chunkSize, players.count)
            let slice = players[chunk..<end]
            groups.append(PlayingGroup(
                name: "Group \(index)",
                playerIds: slice.map(\.id)
            ))
            index += 1
        }
        return groups
    }

    @ViewBuilder
    fileprivate func playingGroupRow(
        group: Binding<PlayingGroup>,
        allPlayers: [Player]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Group name", text: group.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(group.wrappedValue.playerIds.count) players")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Member chips. Tap to remove; menu adds available players from the round.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(group.wrappedValue.playerIds, id: \.self) { pid in
                        if let player = allPlayers.first(where: { $0.id == pid }) {
                            Button {
                                group.wrappedValue.playerIds.removeAll { $0 == pid }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(player.name).font(.caption)
                                    Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(player.avatarColor.color.opacity(0.18))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    let inAnyGroup = Set(viewModel.playingGroupsForSetup.flatMap { $0.playerIds })
                    let unassigned = allPlayers.filter { !inAnyGroup.contains($0.id) }
                    if !unassigned.isEmpty {
                        Menu {
                            ForEach(unassigned) { p in
                                Button(p.name) {
                                    group.wrappedValue.playerIds.append(p.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add")
                            }
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.primaryMuted)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var ninesPointsFields: some View {
        HStack {
            Text("Front 9 / Back 9 Win")
            Spacer()
            TextField("1.0", text: $viewModel.teamPointsPerNineWin)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
        HStack {
            Text("Front 9 / Back 9 Halve")
            Spacer()
            TextField("0.5", text: $viewModel.teamPointsPerNineHalve)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
        HStack {
            Text("Overall 18 Win")
            Spacer()
            TextField("3.0", text: $viewModel.teamPointsPerOverallWin)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
        HStack {
            Text("Overall 18 Halve")
            Spacer()
            TextField("1.5", text: $viewModel.teamPointsPerOverallHalve)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
    }
}

#Preview {
    RoundSetupView(viewModel: SampleData.makeScorecardViewModel())
}

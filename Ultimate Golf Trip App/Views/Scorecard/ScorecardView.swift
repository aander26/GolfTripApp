import SwiftUI

struct ScorecardView: View {
    @Bindable var viewModel: ScorecardViewModel
    @State private var quickEntryMode = false
    @State private var showingDeleteConfirmation = false
    @State private var roundToDelete: Round?
    @State private var showingRoundSummary = false
    @State private var photoImportVM: ScorecardImportViewModel?
    /// Selected playing-group filter for score entry. `nil` = show all players in the round.
    @State private var selectedGroupId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if let round = viewModel.currentRound,
                   let trip = viewModel.currentTrip,
                   let course = round.course {
                    let allRoundPlayers = trip.players.filter { round.playerIds.contains($0.id) }
                    let filteredPlayers = playersForCurrentFilter(round: round, allPlayers: allRoundPlayers)

                    VStack(spacing: 0) {
                        if round.hasPlayingGroups && !round.isComplete {
                            playingGroupChipBar(round: round)
                            if let scorerInfo = scorerInfo(round: round, trip: trip) {
                                DesignatedScorerBanner(
                                    scorerName: scorerInfo.scorerName,
                                    userIsScorer: scorerInfo.userIsScorer,
                                    onTakeOver: { takeOverScoring(round: round, trip: trip) }
                                )
                            }
                        }
                        let lockedReadOnly = isLockedReadOnly(round: round, trip: trip)
                        if round.isComplete {
                            HoleByHoleScoringView(
                                viewModel: viewModel,
                                round: round,
                                course: course,
                                players: allRoundPlayers,
                                isReadOnly: true
                            )
                        } else if quickEntryMode && !lockedReadOnly {
                            QuickEntryView(
                                viewModel: viewModel,
                                round: round,
                                course: course,
                                players: filteredPlayers
                            )
                        } else {
                            HoleByHoleScoringView(
                                viewModel: viewModel,
                                round: round,
                                course: course,
                                players: filteredPlayers,
                                isReadOnly: lockedReadOnly
                            )
                        }
                    }
                    .onAppear { autoSelectMyGroupIfPossible(round: round, trip: trip) }
                } else if let trip = viewModel.currentTrip, !trip.rounds.isEmpty {
                    roundsList(trip: trip)
                } else {
                    noRoundsView
                }
            }
            .navigationTitle("Scorecard")
            .toolbar {
                if let round = viewModel.currentRound {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            viewModel.selectedRoundId = nil
                            viewModel.showingRoundsList = true
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Back to rounds")
                    }
                    if round.isComplete {
                        // Completed round: show Summary button instead of editing controls
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showingRoundSummary = true
                            } label: {
                                Text("Summary")
                                    .fontWeight(.semibold)
                            }
                        }
                    } else {
                        // In-progress round: editing controls in an explicit Menu. We used to
                        // place the quick-entry and photo-import buttons as separate
                        // .secondaryAction items and let SwiftUI auto-collapse them into an
                        // overflow menu, but that behavior was unreliable (the "···" button
                        // sometimes rendered without an expandable menu attached). Building the
                        // Menu ourselves guarantees the expansion works.
                        ToolbarItem(placement: .secondaryAction) {
                            Menu {
                                Button {
                                    quickEntryMode.toggle()
                                } label: {
                                    Label(
                                        quickEntryMode ? "Switch to standard entry" : "Switch to quick entry",
                                        systemImage: quickEntryMode ? "bolt.fill" : "bolt"
                                    )
                                }
                                Button {
                                    if let round = viewModel.currentRound, let course = round.course {
                                        photoImportVM = ScorecardImportViewModel(
                                            scorecardVM: viewModel,
                                            round: round,
                                            course: course
                                        )
                                    }
                                } label: {
                                    Label("Import scorecard from photo", systemImage: "doc.viewfinder")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel("More actions")
                        }
                        if !quickEntryMode {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    if viewModel.currentHole >= viewModel.holeCount {
                                        viewModel.showingRoundComplete = true
                                    } else {
                                        viewModel.nextHole()
                                    }
                                } label: {
                                    Text(viewModel.currentHole >= viewModel.holeCount ? "Finish" : "Next Hole")
                                        .fontWeight(.semibold)
                                }
                                .accessibilityLabel(viewModel.currentHole >= viewModel.holeCount ? "Finish round" : "Next hole")
                            }
                        }
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            viewModel.showingRoundSetup = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Start new round")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingRoundSetup) {
                RoundSetupView(viewModel: viewModel)
            }
            .sheet(item: $photoImportVM) { importVM in
                ScorecardImportFlowView(viewModel: importVM)
            }
            .sheet(isPresented: $showingRoundSummary) {
                if let round = viewModel.currentRound,
                   let trip = viewModel.currentTrip,
                   let course = round.course {
                    NavigationStack {
                        RoundSummaryView(round: round, trip: trip, course: course)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { showingRoundSummary = false }
                                }
                            }
                    }
                }
            }
        }
    }

    private func roundsList(trip: Trip) -> some View {
        List {
            // Day-grouped rounds — rounds within the same calendar day share a section header,
            // and each row shows its index within that day plus the scheduled tee time.
            let groups = groupedRounds(for: trip)
            ForEach(groups, id: \.0) { day, rounds in
                Section(header: Text(dayHeader(for: day))) {
                    ForEach(rounds) { round in
                        let courseName = round.course?.name ?? "Unknown"
                        let index = rounds.firstIndex(of: round).map { $0 + 1 } ?? 1
                        let label = roundDayLabel(index: index, totalOnDay: rounds.count, round: round)
                        Button {
                            viewModel.selectRound(round)
                        } label: {
                            HStack {
                                RoundRowView(round: round, courseName: courseName, dayLabel: label)
                                if round.isComplete {
                                    Spacer()
                                    Text("Review")
                                        .font(.caption)
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                roundToDelete = round
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            Section {
                SyncStatusFooter(
                    isSyncing: viewModel.appState.isCurrentlySyncing,
                    lastSyncCompletedAt: viewModel.appState.lastSyncCompletedAt,
                    iCloudAvailable: viewModel.appState.iCloudAvailable,
                    syncFailed: viewModel.appState.lastSyncFailed
                )
                .listRowBackground(Color.clear)
            }
        }
        .themedList()
        .refreshable {
            await viewModel.appState.syncWithCloud()
        }
        .alert("Delete Round?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                roundToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let round = roundToDelete {
                    viewModel.deleteRound(round.id)
                    roundToDelete = nil
                }
            }
        } message: {
            if let round = roundToDelete {
                Text("This will permanently delete the round at \(round.course?.name ?? "this course") and all its scores.")
            }
        }
    }

    // MARK: - Designated scorer

    /// Returns the scorer's display name and whether the current user is the scorer, for the
    /// currently selected playing group. Nil when no scorer is set.
    private func scorerInfo(round: Round, trip: Trip) -> (scorerName: String, userIsScorer: Bool)? {
        guard let groupId = selectedGroupId,
              let group = round.playingGroups.first(where: { $0.id == groupId }),
              let scorerId = group.scorerPlayerId,
              let scorer = trip.player(withId: scorerId) else { return nil }
        let me = viewModel.appState.myPlayer(in: trip)
        return (scorer.name, me?.id == scorerId)
    }

    /// True when the user is viewing a group that has a designated scorer who isn't them.
    private func isLockedReadOnly(round: Round, trip: Trip) -> Bool {
        guard let info = scorerInfo(round: round, trip: trip) else { return false }
        return !info.userIsScorer
    }

    /// Claim the scorer role for the currently selected playing group.
    private func takeOverScoring(round: Round, trip: Trip) {
        guard let groupId = selectedGroupId,
              let idx = round.playingGroups.firstIndex(where: { $0.id == groupId }),
              let me = viewModel.appState.myPlayer(in: trip) else { return }
        round.playingGroups[idx].scorerPlayerId = me.id
        round.updatedAt = Date()
        viewModel.appState.saveContext()
    }

    // MARK: - Playing-group filter

    /// Filter the round's player list by the selected playing group, if any.
    private func playersForCurrentFilter(round: Round, allPlayers: [Player]) -> [Player] {
        guard round.hasPlayingGroups,
              let groupId = selectedGroupId,
              let group = round.playingGroups.first(where: { $0.id == groupId }) else {
            return allPlayers
        }
        return allPlayers.filter { group.playerIds.contains($0.id) }
    }

    /// On entry to a round with groups, auto-select the current user's group if they're in one.
    private func autoSelectMyGroupIfPossible(round: Round, trip: Trip) {
        guard selectedGroupId == nil, round.hasPlayingGroups else { return }
        guard let me = viewModel.appState.myPlayer(in: trip),
              let mine = round.playingGroup(containing: me.id) else { return }
        selectedGroupId = mine.id
    }

    @ViewBuilder
    private func playingGroupChipBar(round: Round) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                groupChip(title: "All", isSelected: selectedGroupId == nil) {
                    selectedGroupId = nil
                }
                ForEach(round.playingGroups) { group in
                    groupChip(title: group.name, isSelected: selectedGroupId == group.id) {
                        selectedGroupId = group.id
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Theme.background)
    }

    private func groupChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.primary : Theme.cardBackground)
                .foregroundStyle(isSelected ? Theme.textOnPrimary : Theme.textPrimary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.border, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day grouping helpers

    /// Group rounds by calendar day, sorted by date, with each day's rounds sorted by tee time.
    private func groupedRounds(for trip: Trip) -> [(Date, [Round])] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: trip.rounds) { calendar.startOfDay(for: $0.date) }
        return buckets
            .map { ($0.key, $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.0 < $1.0 }
    }

    /// "Tuesday, May 14" or "Today" / "Tomorrow" for the section header.
    private func dayHeader(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    /// "Round 2 · 1:30 PM" — index disambiguates multiple rounds on the same day.
    private func roundDayLabel(index: Int, totalOnDay: Int, round: Round) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeText = timeFormatter.string(from: round.date)
        if totalOnDay > 1 {
            return "Round \(index) · \(timeText)"
        }
        return timeText
    }

    private var noRoundsView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "square.grid.3x3")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("No Rounds Yet")
                .font(.title2)
                .fontWeight(.bold)

            Text("Start a new round to begin tracking scores.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                viewModel.showingRoundSetup = true
            } label: {
                Label("Start Round", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(BoldPrimaryButtonStyle())

            Spacer()
        }
    }
}

#Preview {
    ScorecardView(viewModel: SampleData.makeScorecardViewModel())
}

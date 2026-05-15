import SwiftUI

struct LeaderboardView: View {
    @Bindable var viewModel: LeaderboardViewModel
    @State private var selectedView: LeaderboardTab = .overall

    enum LeaderboardTab: String, CaseIterable {
        case overall = "Overall"
        case round = "By Round"
        case teams = "Teams"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("View", selection: $selectedView) {
                    ForEach(LeaderboardTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                switch selectedView {
                case .overall:
                    overallLeaderboard
                case .round:
                    roundLeaderboard
                case .teams:
                    teamLeaderboard
                }
            }
            .navigationTitle("Leaderboard")
            .navigationDestination(for: LeaderboardEntry.self) { entry in
                if let trip = viewModel.currentTrip {
                    PlayerDetailView(entry: entry, trip: trip)
                } else {
                    ContentUnavailableView("No Trip Selected", systemImage: "exclamationmark.triangle", description: Text("Select a trip to view player details."))
                }
            }
            .onAppear {
                // Keep the leaderboard fresh while it's on screen.
                viewModel.appState.startActivePolling()
            }
            .onDisappear {
                viewModel.appState.stopActivePolling()
            }
        }
    }

    // MARK: - Overall Leaderboard

    private var overallLeaderboard: some View {
        Group {
            let strokeEntries = viewModel.hasStrokePlayRounds ? viewModel.overallLeaderboard : []
            let stablefordEntries = viewModel.hasStablefordRounds ? viewModel.stablefordLeaderboard : []
            if strokeEntries.isEmpty && stablefordEntries.isEmpty {
                emptyLeaderboard
            } else {
                List {
                    if !strokeEntries.isEmpty {
                        Toggle("Show Net Scores", isOn: $viewModel.showingNetScores)
                            .tint(Theme.primary)

                        Section {
                            ForEach(strokeEntries) { entry in
                                NavigationLink(value: entry) {
                                    LeaderboardRowView(
                                        entry: entry,
                                        showNet: viewModel.showingNetScores,
                                        playerColor: viewModel.currentTrip?.player(withId: entry.playerId)?.avatarColor ?? .blue
                                    )
                                }
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stroke Play").sectionHeader()
                                leaderboardHeader
                            }
                        } footer: {
                            Text("Cumulative across stroke-play rounds only. Match play, best ball, and scramble rounds use different scoring units and are shown separately.")
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    if !stablefordEntries.isEmpty {
                        Section {
                            ForEach(stablefordEntries) { entry in
                                NavigationLink(value: entry) {
                                    StablefordRowView(
                                        entry: entry,
                                        playerColor: viewModel.currentTrip?.player(withId: entry.playerId)?.avatarColor ?? .blue
                                    )
                                }
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Stableford").sectionHeader()
                                HStack {
                                    Text("POS").frame(width: 32, alignment: .leading)
                                    Text("PLAYER")
                                    Spacer()
                                    Text("PTS").frame(width: 50, alignment: .trailing)
                                }
                                .font(.caption2)
                                .fontWeight(.bold)
                            }
                        } footer: {
                            Text("Cumulative Stableford points across all Stableford rounds.")
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    let sideGameSummaries = viewModel.tripSideGameSummaries
                    if !sideGameSummaries.isEmpty {
                        Section {
                            ForEach(sideGameSummaries) { summary in
                                tripSideGameRow(summary)
                            }
                        } header: {
                            Text("Trip Side Games").sectionHeader()
                        } footer: {
                            Text("Current live state for each active side game. Tap to open the round's scorecard for details.")
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
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
                .refreshable { await viewModel.appState.syncWithCloud() }
            }
        }
    }

    // MARK: - Round Leaderboard

    private var roundLeaderboard: some View {
        VStack {
            if viewModel.availableRounds.isEmpty {
                ContentUnavailableView("No Rounds Yet", systemImage: "square.grid.3x3", description: Text("Start a round to see per-round standings."))
            }
            // Round Picker
            if !viewModel.availableRounds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableRounds, id: \.id) { round in
                            Button {
                                viewModel.selectRound(round.id)
                            } label: {
                                Text(round.label)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.selectedRoundId == round.id
                                            ? Theme.primary
                                            : Theme.background
                                    )
                                    .foregroundStyle(viewModel.selectedRoundId == round.id ? Theme.textOnPrimary : Theme.textPrimary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            if viewModel.roundLeaderboard.isEmpty {
                if viewModel.selectedRoundId == nil {
                    ContentUnavailableView("Select a Round", systemImage: "flag.fill", description: Text("Choose a round above to view its leaderboard."))
                } else {
                    emptyLeaderboard
                }
            } else {
                List {
                    Section {
                        ForEach(viewModel.roundLeaderboard) { entry in
                            NavigationLink(value: entry) {
                                LeaderboardRowView(
                                    entry: entry,
                                    showNet: viewModel.showingNetScores,
                                    playerColor: viewModel.currentTrip?.player(withId: entry.playerId)?.avatarColor ?? .blue
                                )
                            }
                        }
                    } header: {
                        leaderboardHeader
                    }
                }
                .themedList()
            }
        }
    }

    // MARK: - Team Leaderboard

    private var teamLeaderboard: some View {
        Group {
            if viewModel.teamPointsStandings.isEmpty {
                ContentUnavailableView(
                    "No Teams",
                    systemImage: "person.3",
                    description: Text("Add teams in the Trip tab and complete a round to see team standings.")
                )
            } else {
                List {
                    // Team Points Standings
                    Section("Team Standings") {
                        ForEach(Array(viewModel.teamPointsStandings.enumerated()), id: \.element.id) { index, standing in
                            TeamPointsRowView(standing: standing, position: index + 1)
                        }
                    }

                    // Matchup history — head-to-head across all completed matches.
                    let history = viewModel.teamMatchupHistory
                    if !history.isEmpty {
                        Section {
                            ForEach(history) { record in
                                matchupHistoryRow(record)
                            }
                        } header: {
                            Text("Matchup History")
                        } footer: {
                            Text("Cumulative head-to-head record across every completed match (singles, traditional match play, and 4-ball best ball).")
                                .font(.caption2)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }

                    // Per-Round Match Results
                    Section("Round Results") {
                        if viewModel.teamMatchResults.isEmpty {
                            Text("No results yet. Complete a round with scores to see team competition results.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.teamMatchResults) { roundResult in
                                DisclosureGroup {
                                    // Show nines matches (ninesAndOverall format, or any per-player format with nines toggle)
                                    if !roundResult.ninesMatches.isEmpty {
                                        ForEach(roundResult.ninesMatches) { match in
                                            NinesMatchRowView(
                                                match: match,
                                                trip: viewModel.currentTrip
                                            )
                                        }
                                    }

                                    // Show individual matches for match play formats (without nines)
                                    if !roundResult.individualMatches.isEmpty {
                                        ForEach(roundResult.individualMatches) { match in
                                            IndividualMatchRowView(
                                                match: match,
                                                trip: viewModel.currentTrip,
                                                format: roundResult.scoringRule.format
                                            )
                                        }
                                    }

                                    // Show team nines scores (stroke play / best ball with F9/B9/OA)
                                    if !roundResult.teamNinesScores.isEmpty {
                                        ForEach(roundResult.teamNinesScores) { score in
                                            TeamNinesScoreRowView(
                                                score: score,
                                                allScores: roundResult.teamNinesScores
                                            )
                                        }
                                    }

                                    // Show team scores for stroke play (without nines)
                                    if !roundResult.teamScores.isEmpty {
                                        let winnerTeamId = roundResult.winningTeamId
                                        ForEach(roundResult.teamScores) { teamScore in
                                            TeamScoreRowView(
                                                teamScore: teamScore,
                                                isWinner: teamScore.teamId == winnerTeamId
                                            )
                                        }
                                    }

                                    // Show 4-ball best ball match play results
                                    if !roundResult.bestBallMatches.isEmpty {
                                        ForEach(roundResult.bestBallMatches) { match in
                                            HStack {
                                                Circle()
                                                    .fill(match.team1Color.color)
                                                    .frame(width: 10, height: 10)
                                                Text(match.displayText)
                                                    .font(.subheadline)
                                                Circle()
                                                    .fill(match.team2Color.color)
                                                    .frame(width: 10, height: 10)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                } label: {
                                    RoundMatchHeaderView(
                                        roundResult: roundResult,
                                        trip: viewModel.currentTrip
                                    )
                                }
                            }
                        }
                    }
                }
                .themedList()
            }
        }
    }

    // MARK: - Helpers

    private func matchupHistoryRow(_ record: TeamMatchupRecord) -> some View {
        HStack(spacing: 10) {
            // Two team badges side by side.
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.team1Name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(record.team1Leads ? Theme.primary : Theme.textPrimary)
                    Text("vs")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    Text(record.team2Name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(!record.team1Leads && !record.isTied ? Theme.primary : Theme.textPrimary)
                }
                Text(scoreLabel(for: record))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            Spacer()
            if record.isTied {
                Text("TIED")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.warning.opacity(0.18))
                    .foregroundStyle(Theme.warning)
                    .clipShape(Capsule())
            } else {
                Text(record.team1Leads ? "▲ \(record.team1Name)" : "▲ \(record.team2Name)")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Theme.success.opacity(0.18))
                    .foregroundStyle(Theme.success)
                    .clipShape(Capsule())
            }
        }
    }

    private func scoreLabel(for record: TeamMatchupRecord) -> String {
        // "3-1-1" with a separator hint
        "\(record.team1Wins) - \(record.team2Wins) - \(record.halves) H"
    }

    private func tripSideGameRow(_ summary: TripSideGameSummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: summary.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(summary.gameTitle)
                        .font(.subheadline.weight(.bold))
                    Text("· \(summary.scopeLabel)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Text(summary.statusLine)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var leaderboardHeader: some View {
        HStack {
            Text("POS")
                .frame(width: 32, alignment: .leading)
            Text("PLAYER")
            Spacer()
            Text("THRU")
                .frame(width: 40)
            Text(viewModel.showingNetScores ? "NET" : "GROSS")
                .frame(width: 50, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.bold)
    }

    private var emptyLeaderboard: some View {
        ContentUnavailableView(
            "No Scores Yet",
            systemImage: "trophy",
            description: Text("Start a round and enter scores to see the leaderboard.")
        )
    }
}

// MARK: - Stableford Row

/// Compact row that shows Stableford points instead of gross/net — used in the format-aware
/// Overall leaderboard's Stableford section.
struct StablefordRowView: View {
    let entry: LeaderboardEntry
    let playerColor: PlayerColor

    var body: some View {
        HStack(spacing: 8) {
            Text(entry.positionDisplay)
                .font(.headline)
                .fontWeight(.bold)
                .frame(width: 32, alignment: .leading)
                .foregroundStyle(entry.position == 1 ? Theme.primary : Theme.textPrimary)

            Circle()
                .fill(playerColor.color)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(entry.playerName.prefix(1)))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.playerName).font(.subheadline.weight(.semibold))
                Text("\(entry.totalRounds) round\(entry.totalRounds == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
            Text("\(entry.stablefordPoints)")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    let showNet: Bool
    let playerColor: PlayerColor

    var body: some View {
        HStack(spacing: 8) {
            // Position
            Text(entry.positionDisplay)
                .font(.headline)
                .fontWeight(.bold)
                .frame(width: 32, alignment: .leading)
                .foregroundStyle(positionColor)

            // Player Info
            Circle()
                .fill(playerColor.color)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(String(entry.playerName.prefix(1)))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.playerName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("R\(entry.roundsCompleted)/\(entry.totalRounds)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Thru
            Text(entry.thruDisplay)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40)

            // Score
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(showNet ? entry.totalNet : entry.totalGross)")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(showNet ? entry.formattedScoreToPar : entry.formattedGrossScoreToPar)
                    .font(.caption)
                    .foregroundStyle(scoreColor)
            }
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Position \(entry.position), \(entry.playerName), \(showNet ? "net" : "gross") \(showNet ? entry.totalNet : entry.totalGross), \(showNet ? entry.formattedScoreToPar : entry.formattedGrossScoreToPar) to par")
    }

    private var positionColor: Color {
        switch entry.position {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }

    private var scoreColor: Color {
        let score = showNet ? entry.netScoreToPar : entry.scoreToPar
        if score < 0 { return .birdie }
        if score == 0 { return .par }
        return .bogey
    }
}

#Preview {
    LeaderboardView(viewModel: SampleData.makeLeaderboardViewModel())
}

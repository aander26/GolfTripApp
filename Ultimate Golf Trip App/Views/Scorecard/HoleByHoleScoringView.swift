import SwiftUI

struct HoleByHoleScoringView: View {
    @Bindable var viewModel: ScorecardViewModel
    let round: Round
    let course: Course
    let players: [Player]
    var isReadOnly: Bool = false

    var currentHoleInfo: Hole? {
        course.holes.first { $0.number == viewModel.currentHole }
    }

    /// In scramble mode, replace the per-player name with the team name so the row reads as
    /// the team's card, not "Alex's card." Non-scramble rounds use the player's name.
    private func scrambleRowName(for player: Player) -> String? {
        guard round.format == .scramble, let teamName = player.team?.name else { return nil }
        return teamName
    }

    /// For scramble rounds, render one row per team (using the first teammate as a stand-in)
    /// so the scorer enters a single team score that mirrors to all teammates.
    private var displayPlayers: [Player] {
        guard round.format == .scramble else { return players }
        var seenTeams: Set<UUID> = []
        return players.reduce(into: [Player]()) { acc, player in
            if let teamId = player.team?.id {
                if !seenTeams.contains(teamId) {
                    seenTeams.insert(teamId)
                    acc.append(player)
                }
            } else {
                // Players without a team still get their own row.
                acc.append(player)
            }
        }
    }

    /// Show the putts UI when either the round opts in OR an active challenge needs putts data.
    private var showsPutts: Bool {
        round.trackPutts || viewModel.puttsRequiredForCurrentRound
    }

    /// Live match status — hidden for non-match formats and rounds without scores yet.
    /// Personalized: the headline prefers the current user's pairing.
    private var matchBannerState: LiveMatchBannerState {
        guard let trip = viewModel.currentTrip else { return .hidden }
        return LiveMatchStatusViewModel.state(
            round: round,
            trip: trip,
            course: course,
            currentPlayerId: viewModel.appState.myPlayer(in: trip)?.id
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hole Navigation Header
            holeHeader

            // Hole Info
            if let hole = currentHoleInfo {
                holeInfoBar(hole: hole)
            }

            // Live match status banner (hidden for non-match formats)
            LiveMatchStatusBanner(state: matchBannerState, totalHoles: course.holes.count)

            // Player Scores
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(displayPlayers) { player in
                        PlayerScoreCard(
                            player: player,
                            holeNumber: viewModel.currentHole,
                            score: viewModel.scoreForPlayer(player.id, roundId: round.id, holeNumber: viewModel.currentHole),
                            showsPutts: showsPutts,
                            puttsRequired: isReadOnly ? false : viewModel.puttsRequiredForCurrentRound,
                            isReadOnly: isReadOnly,
                            displayName: scrambleRowName(for: player),
                            onScoreChanged: { strokes, putts in
                                viewModel.updateScore(
                                    roundId: round.id,
                                    playerId: player.id,
                                    holeNumber: viewModel.currentHole,
                                    strokes: strokes,
                                    putts: putts
                                )
                            }
                        )
                    }
                }
                .padding()
            }

            // Totals Bar
            totalsBar

            // Navigation Buttons
            navigationBar
        }
        .onAppear {
            // Poll CloudKit every 20s while this view is on screen so the live banner /
            // leaderboard reflect remote scorers without waiting for a silent push.
            if !isReadOnly {
                viewModel.appState.startActivePolling()
            }
        }
        .onDisappear {
            viewModel.appState.stopActivePolling()
        }
        .sheet(isPresented: $viewModel.showingRoundComplete) {
            RoundCompleteSheet(viewModel: viewModel, round: round, course: course, players: players)
        }
        .alert("Scores Missing", isPresented: $viewModel.showingMissingStrokesAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please enter strokes for all players before moving to the next hole.")
        }
        .alert("Putts Required", isPresented: $viewModel.showingPuttsRequiredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            let names = viewModel.puttsRequiredChallengeNames
            if names.count == 1 {
                Text("Please enter putts for all players. This data is required by the \"\(names[0])\" challenge.")
            } else {
                Text("Please enter putts for all players. This data is required by active challenges.")
            }
        }
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        HStack {
            Button {
                viewModel.previousHole()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .disabled(viewModel.currentHole <= 1)
            .accessibilityLabel("Previous hole")

            Spacer()

            VStack(spacing: 2) {
                Text("Hole \(viewModel.currentHole)")
                    .font(.title2)
                    .fontWeight(.bold)

                if viewModel.currentHole == 10 {
                    Text("Back Nine")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Hole \(viewModel.currentHole) of \(course.holes.count)")

            Spacer()

            Button {
                viewModel.nextHole()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .disabled(viewModel.currentHole >= course.holes.count)
            .accessibilityLabel("Next hole")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    // MARK: - Hole Info

    private func holeInfoBar(hole: Hole) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("PAR")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(hole.par)")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            VStack(spacing: 2) {
                Text("YARDS")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(hole.yardage)")
                    .font(.title3)
                    .fontWeight(.bold)
            }

            VStack(spacing: 2) {
                Text("HDCP")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(hole.handicapRating)")
                    .font(.title3)
                    .fontWeight(.bold)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Par \(hole.par), \(hole.yardage) yards, handicap \(hole.handicapRating)")
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.primaryMuted)
    }

    // MARK: - Totals Bar

    private var totalsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(players) { player in
                    let totals = viewModel.totalForPlayer(player.id, roundId: round.id)
                    VStack(spacing: 2) {
                        Text(player.name.split(separator: " ").first.map(String.init) ?? player.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text("\(totals.gross)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if totals.net != totals.gross {
                                Text("(\(totals.net))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(player.name): gross \(totals.gross)\(totals.net != totals.gross ? ", net \(totals.net)" : "")")
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Theme.cardBackground)
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack(spacing: 16) {
            // Hole selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(1...max(course.holes.count, 1)), id: \.self) { hole in
                        Button {
                            viewModel.goToHole(hole)
                        } label: {
                            Text("\(hole)")
                                .font(.caption)
                                .fontWeight(viewModel.currentHole == hole ? .bold : .regular)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .frame(minWidth: 44, minHeight: 44)
                                .background(
                                    Circle()
                                        .fill(viewModel.currentHole == hole ? Theme.primary : Theme.background)
                                )
                                .foregroundStyle(viewModel.currentHole == hole ? .white : .primary)
                        }
                        .accessibilityLabel("Hole \(hole)\(viewModel.currentHole == hole ? ", current" : "")")
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(Theme.background)
    }
}

// MARK: - Player Score Card

struct PlayerScoreCard: View {
    let player: Player
    let holeNumber: Int
    let score: HoleScore?
    var showsPutts: Bool = true
    var puttsRequired: Bool = false
    var isReadOnly: Bool = false
    /// Optional override for the displayed name (used for scramble rounds where one row
    /// represents a whole team, not a single player).
    var displayName: String? = nil
    let onScoreChanged: (Int, Int) -> Void

    @State private var strokes: Int = 0
    @State private var putts: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            // Player Name
            HStack {
                Circle()
                    .fill(player.avatarColor.color)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(player.initials)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text(displayName ?? player.name)
                        .font(.headline)
                    if let score = score, score.strokesReceived > 0 {
                        Text("+\(score.strokesReceived) stroke\(score.strokesReceived > 1 ? "s" : "")")
                            .font(.caption)
                            .foregroundStyle(Theme.primary)
                    }
                }

                Spacer()

                if let score = score, score.isCompleted {
                    Text(score.scoreLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(score.scoreColor)
                        .accessibilityLabel("Score: \(score.scoreLabel)")
                }
            }

            if isReadOnly {
                // Read-only display: just show the scores without controls
                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text("STROKES")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(strokes)")
                            .font(.system(size: 28, weight: .bold))
                    }
                    if putts > 0 {
                        Divider().frame(height: 40)
                        VStack(spacing: 2) {
                            Text("PUTTS")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(putts)")
                                .font(.system(size: 28, weight: .bold))
                        }
                    }
                    if let score = score, score.isCompleted {
                        Divider().frame(height: 40)
                        VStack(spacing: 2) {
                            Text("NET")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(score.netStrokes)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(score.netScoreColor)
                        }
                    }
                }
            } else {
            // Score Stepper
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("STROKES")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button {
                            if strokes > 1 {
                                strokes -= 1
                                onScoreChanged(strokes, putts)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Decrease strokes")
                        .accessibilityHint("Current strokes: \(strokes)")

                        Text("\(strokes)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .frame(minWidth: 50)
                            .accessibilityLabel("\(strokes) strokes")

                        Button {
                            strokes += 1
                            onScoreChanged(strokes, putts)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Increase strokes")
                        .accessibilityHint("Current strokes: \(strokes)")
                    }
                }

                if showsPutts {
                Divider()
                    .frame(height: 50)

                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("PUTTS")
                            .font(.caption2)
                            .foregroundStyle(puttsRequired && strokes > 0 && putts == 0 ? Theme.error : .secondary)
                        if puttsRequired {
                            Text("*")
                                .font(.caption2)
                                .foregroundStyle(Theme.error)
                        }
                    }

                    HStack(spacing: 16) {
                        Button {
                            if putts > 0 {
                                putts -= 1
                                onScoreChanged(strokes, putts)
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Decrease putts")
                        .accessibilityHint("Current putts: \(putts)")

                        Text("\(putts)")
                            .font(.system(.title, design: .rounded).weight(.bold))
                            .foregroundStyle(puttsRequired && strokes > 0 && putts == 0 ? Theme.error : Theme.textPrimary)
                            .frame(minWidth: 50)
                            .accessibilityLabel("\(putts) putts")

                        Button {
                            // Don't allow putts to exceed strokes
                            if strokes == 0 || putts < strokes {
                                putts += 1
                                onScoreChanged(strokes, putts)
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(strokes == 0 || putts >= strokes ? .secondary : Theme.primary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .disabled(strokes == 0 || putts >= strokes)
                        .accessibilityLabel("Increase putts")
                        .accessibilityHint("Current putts: \(putts)")
                    }
                }
                } // end if showsPutts
            }
            } // end else (editable mode)
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { loadScore() }
        .onChange(of: holeNumber) { _, _ in loadScore() }
    }

    private func loadScore() {
        strokes = score?.strokes ?? 0
        putts = score?.putts ?? 0
    }
}

// MARK: - Round Complete Sheet

struct RoundCompleteSheet: View {
    @Bindable var viewModel: ScorecardViewModel
    let round: Round
    let course: Course
    let players: [Player]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.primary)

                    Text("Round Complete!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(course.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)

                // Score Summary
                VStack(spacing: 0) {
                    ForEach(players) { player in
                        if let card = round.scorecard(forPlayer: player.id) {
                            HStack {
                                Circle()
                                    .fill(player.avatarColor.color)
                                    .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .frame(minWidth: 44, minHeight: 44)
                                    .overlay {
                                        Text(player.initials)
                                            .font(.system(size: 10))
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                    }

                                Text(player.name)
                                    .font(.body)

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Gross: \(card.totalGross)")
                                        .font(.subheadline)
                                    if card.totalNet != card.totalGross {
                                        Text("Net: \(card.totalNet)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .fontWeight(.semibold)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal)

                            if player.id != players.last?.id {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        viewModel.completeRound(round.id)
                        viewModel.selectedRoundId = nil
                        dismiss()
                    } label: {
                        Text("End Round")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primary)

                    Button {
                        dismiss()
                    } label: {
                        Text("Continue Editing Scores")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Round Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    HoleByHoleScoringView(
        viewModel: SampleData.makeScorecardViewModel(),
        round: SampleData.round,
        course: SampleData.course,
        players: SampleData.playersWithTeams
    )
}

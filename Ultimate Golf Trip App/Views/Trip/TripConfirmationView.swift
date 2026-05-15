import SwiftUI

/// Pre-event review screen. Aggregates teams, rounds (with matchups + playing groups),
/// challenges, and side games into a structured, read-only summary so the trip organizer
/// (and other players) can verify the setup before play begins.
///
/// Confirmation here doesn't lock anything — it's purely a "I've reviewed this" signal.
struct TripConfirmationView: View {
    @State var viewModel: TripConfirmationViewModel

    var body: some View {
        Group {
            if viewModel.trip == nil {
                ContentUnavailableView(
                    "No Trip Selected",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Select a trip to review its pre-event setup.")
                )
            } else if !viewModel.hasContent {
                ContentUnavailableView(
                    "Nothing to confirm yet",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Add teams, courses, rounds, or challenges to your trip — then come back here to review.")
                )
            } else {
                content
            }
        }
        .navigationTitle("Review Setup")
        .navigationBarTitleDisplayMode(.inline)
        .background(Theme.background)
    }

    // MARK: - Layout

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                teamsSection
                roundsSection
                tripWideChallengesSection
                tripWideGamesSection
                confirmationFooter
                Color.clear.frame(height: 24)
            }
            .padding(.horizontal)
            .padding(.top, 12)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.trip?.name ?? "")
                .font(.title3.weight(.bold))
            if let trip = viewModel.trip {
                Text(trip.dateRange)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: 8) {
                summaryPill(icon: "person.3.fill",
                            count: viewModel.trip?.players.count ?? 0,
                            label: "players")
                summaryPill(icon: "flag.2.crossed.fill",
                            count: viewModel.teams.count,
                            label: "teams")
                summaryPill(icon: "square.grid.3x3",
                            count: viewModel.rounds.count,
                            label: "rounds")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func summaryPill(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text("\(count) \(label)")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Theme.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.primaryMuted)
        .clipShape(Capsule())
    }

    // MARK: - Teams

    @ViewBuilder
    private var teamsSection: some View {
        if !viewModel.teams.isEmpty {
            sectionCard("Teams", count: viewModel.teams.count) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.teams) { team in
                        teamRow(team)
                    }
                }
            }
        }
    }

    private func teamRow(_ team: Team) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(team.color.color)
                    .frame(width: 10, height: 10)
                Text(team.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(team.players.count) player\(team.players.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            if team.players.isEmpty {
                Text("No players assigned")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                FlowText(items: team.players.map(\.name))
            }
        }
        .padding(10)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Rounds

    @ViewBuilder
    private var roundsSection: some View {
        if !viewModel.rounds.isEmpty {
            sectionCard("Rounds", count: viewModel.rounds.count) {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.rounds) { round in
                        roundCard(round)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func roundCard(_ round: ConfirmationRoundSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            VStack(alignment: .leading, spacing: 2) {
                Text(round.dayLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.primary)
                Text(round.courseName)
                    .font(.subheadline.weight(.bold))
            }

            // Format + scoring + putts pills
            FlowChips(chips: roundChips(round))

            if let desc = round.formatDescription {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if let teamLabel = round.teamScoringLabel {
                detailRow(label: "Team competition", value: teamLabel)
            }

            // Pairings
            if !round.pairings.isEmpty {
                Divider()
                labeledSection("Matchups") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(round.pairings, id: \.self) { pairing in
                            HStack(spacing: 6) {
                                Image(systemName: "person.2.fill")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textSecondary)
                                Text(pairing).font(.caption)
                            }
                        }
                    }
                }
            }

            // Playing groups
            if !round.playingGroups.isEmpty {
                Divider()
                labeledSection("Playing Groups") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(round.playingGroups) { group in
                            playingGroupRow(group)
                        }
                    }
                }
            }

            // Per-round challenges
            if !round.challenges.isEmpty {
                Divider()
                labeledSection("Round Challenges") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(round.challenges) { c in
                            challengeRow(c, showScope: false)
                        }
                    }
                }
            }

            // Per-round side games
            if !round.games.isEmpty {
                Divider()
                labeledSection("Round Side Games") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(round.games) { g in
                            gameRow(g, showScope: false)
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1))
    }

    private func roundChips(_ round: ConfirmationRoundSummary) -> [FlowChip] {
        var chips: [FlowChip] = []
        chips.append(.init(icon: "square.grid.3x3", text: round.formatLabel, accent: .primary))
        chips.append(.init(icon: "person.fill", text: "\(round.playerCount) players", accent: .secondary))
        chips.append(.init(
            icon: round.puttsLabel == "Tracking putts" ? "scope" : "scope.slash",
            text: round.puttsLabel,
            accent: .secondary
        ))
        return chips
    }

    private func playingGroupRow(_ group: ConfirmationPlayingGroupSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(group.name)
                    .font(.caption.weight(.bold))
                if let tee = group.teeTimeLabel {
                    Text("· \(tee)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                if group.startingHole != 1 {
                    Text("· starts hole \(group.startingHole)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let scorer = group.scorerName {
                    HStack(spacing: 2) {
                        Image(systemName: "pencil.circle.fill").font(.caption2)
                        Text("\(scorer) scoring").font(.caption2)
                    }
                    .foregroundStyle(Theme.primary)
                }
            }
            FlowText(items: group.playerNames)
        }
    }

    // MARK: - Trip-wide challenges

    @ViewBuilder
    private var tripWideChallengesSection: some View {
        if !viewModel.tripWideChallenges.isEmpty {
            sectionCard("Trip-Wide Challenges", count: viewModel.tripWideChallenges.count) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.tripWideChallenges) { c in
                        challengeRow(c, showScope: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tripWideGamesSection: some View {
        if !viewModel.tripWideGames.isEmpty {
            sectionCard("Trip-Wide Side Games", count: viewModel.tripWideGames.count) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.tripWideGames) { g in
                        gameRow(g, showScope: true)
                    }
                }
            }
        }
    }

    private func challengeRow(_ c: ConfirmationChallengeSummary, showScope: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(c.name.isEmpty ? c.typeLabel : c.name)
                    .font(.subheadline.weight(.semibold))
                Text("· \(c.typeLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                Spacer()
                if showScope {
                    Text(c.scopeLabel)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Text(c.description)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 10) {
                if let stakes = c.stakesLabel {
                    Label(stakes, systemImage: "dollarsign.circle")
                        .font(.caption2)
                        .foregroundStyle(Theme.primary)
                }
                if !c.participantNames.isEmpty {
                    Label("\(c.participantNames.count) participant\(c.participantNames.count == 1 ? "" : "s")",
                          systemImage: "person.2")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func gameRow(_ g: ConfirmationGameSummary, showScope: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(g.typeName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if showScope {
                    Text(g.scopeLabel)
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(spacing: 10) {
                Label(g.stakesLabel, systemImage: "dollarsign.circle")
                    .font(.caption2)
                    .foregroundStyle(Theme.primary)
                if !g.participantNames.isEmpty {
                    Label("\(g.participantNames.count) playing", systemImage: "person.2")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                if let holes = g.designatedHolesLabel {
                    Label(holes, systemImage: "flag")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Confirmation footer

    private var confirmationFooter: some View {
        VStack(spacing: 12) {
            if let progress = viewModel.progressLabel {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.primary)
                    Text(progress)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }

            if !viewModel.confirmedPlayers.isEmpty {
                FlowText(items: viewModel.confirmedPlayers.map(\.name))
            }

            if viewModel.currentUserIsGuest {
                Text("You're viewing as a guest — only trip members can confirm.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            } else if viewModel.currentUserHasConfirmed {
                VStack(spacing: 8) {
                    Label("You've confirmed", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.success)
                    Text("Confirmation doesn't lock the setup — you can still edit anything from the Trip tab.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Undo confirmation") { viewModel.unconfirm() }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            } else {
                VStack(spacing: 8) {
                    Button {
                        viewModel.confirm()
                    } label: {
                        Label("Confirm & Ready to Play", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BoldPrimaryButtonStyle())
                    Text("Marks the setup as reviewed. Doesn't lock anything — keep editing from the Trip tab if needed.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.primaryMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Section / layout helpers

    @ViewBuilder
    private func sectionCard<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.uppercased())
                    .sectionHeader()
                Spacer()
                Text("\(count)")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(Theme.textSecondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    @ViewBuilder
    private func labeledSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(0.4)
            content()
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Small layout primitives used above

/// A chip describing one round attribute (format, player count, putts).
private struct FlowChip: Hashable {
    enum Accent { case primary, secondary }
    let icon: String
    let text: String
    let accent: Accent
}

/// Horizontal wrap of small attribute chips. Falls back to a horizontal scroll on very narrow widths.
private struct FlowChips: View {
    let chips: [FlowChip]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips, id: \.self) { chip in
                    HStack(spacing: 4) {
                        Image(systemName: chip.icon).font(.caption2)
                        Text(chip.text).font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(chip.accent == .primary ? Theme.primaryMuted : Theme.border.opacity(0.3))
                    .foregroundStyle(chip.accent == .primary ? Theme.primary : Theme.textSecondary)
                    .clipShape(Capsule())
                }
            }
        }
    }
}

/// Simple comma-joined wrapping text — used for player rosters within a card.
private struct FlowText: View {
    let items: [String]

    var body: some View {
        Text(items.joined(separator: ", "))
            .font(.caption)
            .foregroundStyle(Theme.textPrimary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

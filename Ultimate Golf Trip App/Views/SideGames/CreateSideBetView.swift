import SwiftUI

struct CreateSideBetView: View {
    @Bindable var viewModel: ChallengesViewModel
    @Environment(\.dismiss) private var dismiss

    /// Scorecard-based challenge types.
    private var scorecardTypes: [BetType] {
        [.lowRound, .headToHeadRound, .mostBirdies, .fewestPutts, .fewest3Putts, .most3Putts]
    }

    /// Manual / custom challenge types.
    private var manualTypes: [BetType] {
        [.custom]
    }

    private var canSave: Bool {
        guard !viewModel.newBetName.isEmpty,
              viewModel.newBetParticipants.count >= 2 else { return false }
        if viewModel.newBetType.isRoundBased && !viewModel.newBetIsTripWide {
            guard viewModel.newBetRoundId != nil else { return false }
        }
        if viewModel.newBetType.requiresTwoPlayers {
            guard viewModel.newBetParticipants.count == 2 else { return false }
        }
        if viewModel.newBetType.isCustom {
            guard !viewModel.newBetCustomMetricName.isEmpty else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Challenge Type (hidden when coming from template)
                if !viewModel.isFromTemplate {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Scorecard-Based")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 8) {
                                ForEach(scorecardTypes) { type in
                                    challengeTypeChip(type)
                                }
                            }

                            Text("Custom / Manual")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)

                            FlowLayout(spacing: 8) {
                                ForEach(manualTypes) { type in
                                    challengeTypeChip(type)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Challenge Type")
                    } footer: {
                        Text(viewModel.newBetType.description)
                    }
                }

                // MARK: - Template Summary (shown when coming from template)
                if viewModel.isFromTemplate {
                    Section {
                        HStack {
                            Image(systemName: viewModel.newBetType.icon)
                                .foregroundStyle(Theme.primary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.newBetType.displayName)
                                    .font(.headline)
                                Text(viewModel.newBetType.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Gross/Net toggle — prominent for template flow
                        if viewModel.newBetType.supportsNetScoring {
                            Picker("Scoring", selection: $viewModel.newBetUseNetScoring) {
                                Text("Gross").tag(false)
                                Text("Net (Handicap)").tag(true)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                // MARK: - Challenge Name
                Section("Challenge Name") {
                    TextField("e.g. Low Round Day 1", text: $viewModel.newBetName)
                }

                // MARK: - Scope Selection (Single Round vs Trip-Wide)
                if viewModel.newBetType.supportsTripWide && (viewModel.newBetType.isRoundBased || viewModel.newBetType.isCustom) {
                    Section {
                        Picker("Scope", selection: $viewModel.newBetIsTripWide) {
                            Text("Single Round").tag(false)
                            Text("Entire Trip").tag(true)
                        }
                        .pickerStyle(.segmented)

                        if viewModel.newBetIsTripWide {
                            HStack(spacing: 6) {
                                Image(systemName: "repeat")
                                    .foregroundStyle(Theme.primary)
                                Text(viewModel.newBetType.isCustom
                                     ? "Entries accumulate over the trip"
                                     : "Aggregates scorecard data across all trip rounds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Scope")
                    }
                }

                // MARK: - Round Selection (single-round scorecard challenges only)
                if viewModel.newBetType.isRoundBased && !viewModel.newBetIsTripWide {
                    Section("Round") {
                        if let trip = viewModel.currentTrip, !trip.rounds.isEmpty {
                            Picker("Round", selection: $viewModel.newBetRoundId) {
                                Text("Select a round").tag(UUID?.none)
                                ForEach(trip.rounds) { round in
                                    Text("\(round.course?.name ?? "Unknown") — \(round.formattedDate)")
                                        .tag(UUID?.some(round.id))
                                }
                            }

                            // Gross/Net toggle (only shown in non-template flow, template shows it above)
                            if !viewModel.isFromTemplate && viewModel.newBetType.supportsNetScoring {
                                Toggle("Use Net Scoring", isOn: $viewModel.newBetUseNetScoring)

                                if viewModel.newBetUseNetScoring {
                                    Text("Scores adjusted by handicap strokes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if viewModel.newBetType.requiresPuttsTracking {
                                HStack(spacing: 6) {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.blue)
                                    Text("Requires putts to be entered on the scorecard")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("No rounds available. Add a round first.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Custom Metric (custom type only)
                if viewModel.newBetType.isCustom {
                    Section("Custom Metric") {
                        TextField("What are you tracking? (e.g. Beers Drank)", text: $viewModel.newBetCustomMetricName)

                        Picker("Winner", selection: $viewModel.newBetCustomHighestWins) {
                            Text("Highest Value Wins").tag(true)
                            Text("Lowest Value Wins").tag(false)
                        }

                        Text("Players enter values manually. Example: beers drank, steps walked, hours slept.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Participants
                Section {
                    if let trip = viewModel.currentTrip {
                        ForEach(trip.players) { player in
                            Button {
                                toggleParticipant(player.id)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(player.avatarColor.color)
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            Text(String(player.name.prefix(1)))
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }

                                    Text(player.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: viewModel.newBetParticipants.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.newBetParticipants.contains(player.id) ? Theme.primary : .secondary)
                                }
                            }
                            .accessibilityLabel("\(player.name), \(viewModel.newBetParticipants.contains(player.id) ? "selected" : "not selected")")
                            .accessibilityAddTraits(viewModel.newBetParticipants.contains(player.id) ? .isSelected : [])
                        }
                    }
                } header: {
                    HStack {
                        Text("Participants")
                        Spacer()
                        Text("\(viewModel.newBetParticipants.count) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    if viewModel.newBetType.requiresTwoPlayers {
                        Text("This challenge type requires exactly 2 participants.")
                    }
                }

                // MARK: - Stakes
                Section("Stakes") {
                    TextField("e.g. Bragging Rights, $10, Dinner", text: $viewModel.newBetStake)

                    Toggle("Pool Mode", isOn: $viewModel.newBetIsPot)

                    if viewModel.newBetIsPot {
                        HStack {
                            Text("Per-Player Entry")
                            Spacer()
                            TextField("0", text: $viewModel.newBetPotAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("pts")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.isFromTemplate ? "Set Up Challenge" : "New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: viewModel.newBetUseNetScoring) { _, useNet in
                // Update name to reflect gross/net when in template mode
                if viewModel.isFromTemplate && viewModel.newBetType.supportsNetScoring {
                    let base = viewModel.newBetType.displayName
                    viewModel.newBetName = useNet ? "\(base) (Net)" : "\(base) (Gross)"
                }
            }
            .onChange(of: viewModel.newBetType) { _, newType in
                viewModel.newBetRequiresPutts = newType.requiresPuttsTracking
                // Clear round selection when switching to non-round-based type
                if !newType.isRoundBased {
                    viewModel.newBetRoundId = nil
                }
                // Clear custom fields when switching away from custom
                if !newType.isCustom {
                    viewModel.newBetCustomMetricName = ""
                    viewModel.newBetCustomHighestWins = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetBetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createBet()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func challengeTypeChip(_ type: BetType) -> some View {
        Button {
            viewModel.newBetType = type
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.caption2)
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(viewModel.newBetType == type ? Theme.primary : Theme.primaryLight)
            .foregroundStyle(viewModel.newBetType == type ? .white : Theme.primary)
            .clipShape(Capsule())
        }
        .accessibilityLabel("\(type.displayName) challenge type")
        .accessibilityAddTraits(viewModel.newBetType == type ? .isSelected : [])
    }

    private func toggleParticipant(_ playerId: UUID) {
        if viewModel.newBetParticipants.contains(playerId) {
            viewModel.newBetParticipants.remove(playerId)
        } else {
            viewModel.newBetParticipants.insert(playerId)
        }
    }
}

// MARK: - Flow Layout (wrapping horizontal layout for chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

#Preview {
    let appState = SampleData.makeAppState()
    CreateSideBetView(viewModel: ChallengesViewModel(appState: appState))
}

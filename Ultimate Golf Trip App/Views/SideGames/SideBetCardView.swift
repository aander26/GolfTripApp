import SwiftUI

struct SideBetCardView: View {
    let bet: SideBet
    @Bindable var viewModel: ChallengesViewModel
    @State private var showingWinnerPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCompleteConfirmation = false
    @State private var showingEditBet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: bet.betType.icon)
                    .foregroundStyle(Theme.primary)
                Text(bet.name)
                    .font(.headline)

                if bet.isPotBet {
                    Text("POOL")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Spacer()

                if bet.isPotBet && bet.potAmount > 0 {
                    Text("\(String(format: "%.0f", bet.totalPool)) pts")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryLight)
                        .clipShape(Capsule())
                } else {
                    Text(bet.stake)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.primaryLight)
                        .clipShape(Capsule())
                }
            }

            // Info line: round details
            HStack(spacing: 4) {
                if let roundName = bet.roundDisplayName {
                    Image(systemName: "flag.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(roundName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("\u{00b7}")
                    .foregroundStyle(.secondary)
                Text(bet.betType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if bet.challengeType.supportsNetScoring {
                    Text("\u{00b7}")
                        .foregroundStyle(.secondary)
                    Text(bet.useNetScoring ? "Net" : "Gross")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.primary)
                }
                if bet.isPotBet && bet.potAmount > 0 {
                    Text("\u{00b7} \(String(format: "%.0f", bet.potAmount)) pts/player")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Participant standings (all challenge types via liveStandings)
            let standings = viewModel.liveStandings(for: bet)
            if !standings.isEmpty {
                VStack(spacing: 4) {
                    // Metric header
                    HStack {
                        Text(metricHeaderLabel)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if bet.isActive && standings.contains(where: { $0.value > 0 }) {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 5, height: 5)
                                Text("LIVE")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    ForEach(standings) { standing in
                        HStack(spacing: 8) {
                            if standing.isLeader {
                                Image(systemName: bet.isCompleted ? "trophy.fill" : "arrow.right")
                                    .font(.system(size: 8))
                                    .foregroundStyle(bet.isCompleted ? .yellow : Theme.primary)
                                    .frame(width: 10)
                            } else {
                                Spacer().frame(width: 10)
                            }

                            Text(standing.playerName.split(separator: " ").first.map(String.init) ?? standing.playerName)
                                .font(.caption)
                                .fontWeight(standing.isLeader ? .semibold : .regular)
                                .frame(width: 55, alignment: .leading)

                            GeometryReader { geometry in
                                let maxVal = standings.map(\.value).max() ?? 1
                                let barWidth = maxVal > 0 ? (standing.value / maxVal) * geometry.size.width : 0
                                if standing.value > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(standing.isLeader ? Theme.primary : Theme.primary.opacity(0.3))
                                        .frame(width: max(barWidth, 2), height: 14)
                                }
                            }
                            .frame(height: 14)

                            Text(standing.label)
                                .font(.caption.bold())
                                .foregroundStyle(standing.isLeader ? Theme.primary : .primary)
                                .frame(width: 65, alignment: .trailing)
                        }
                    }
                }
            }

            // Scorecard-based indicator or custom value entry
            if bet.isRoundBased && bet.isActive {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.primary)
                    Text("Auto-calculated from scorecard")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if bet.challengeType.isCustom && bet.isActive {
                CustomValueEntryView(bet: bet, viewModel: viewModel)
            }

            // Status / Actions
            HStack {
                if bet.isCompleted {
                    if let winnerId = bet.winnerId,
                       let winner = viewModel.currentTrip?.player(withId: winnerId) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption)
                                Text("\(winner.name) wins!")
                                    .font(.caption.bold())
                                    .foregroundStyle(Theme.primary)
                            }
                            if !bet.stake.isEmpty {
                                Text(bet.stake)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        // Completed with no winner = tied
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Image(systemName: "equal.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text("Tied — No Winner")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                            }
                            Button {
                                showingWinnerPicker = true
                            } label: {
                                Text("Declare Winner")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                } else {
                    // Prominent "Complete" button when there's a leader
                    Button {
                        showingCompleteConfirmation = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("Complete")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                }

                Spacer()

                if bet.isActive {
                    Menu {
                        Button {
                            viewModel.startEditingBet(bet)
                            showingEditBet = true
                        } label: {
                            Label("Edit Challenge", systemImage: "pencil")
                        }
                        Button {
                            showingWinnerPicker = true
                        } label: {
                            Label("Declare Winner", systemImage: "trophy")
                        }
                        Button {
                            viewModel.completeBet(bet.id)
                        } label: {
                            Label("Auto-Settle from Scores", systemImage: "chart.bar")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .accessibilityLabel("Challenge actions for \(bet.name)")
                }
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingWinnerPicker) {
            BetWinnerPickerSheet(bet: bet, viewModel: viewModel)
        }
        .alert("Delete Challenge", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                viewModel.deleteBet(bet.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \"\(bet.name)\"? This cannot be undone.")
        }
        .sheet(isPresented: $showingEditBet) {
            NavigationStack {
                Form {
                    Section("Challenge Details") {
                        TextField("Name", text: $viewModel.editBetName)
                        TextField("Stake (e.g. Bragging Rights, $20)", text: $viewModel.editBetStake)
                    }
                }
                .navigationTitle("Edit Challenge")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingEditBet = false
                            viewModel.showingEditBet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.saveBetEdits()
                            showingEditBet = false
                        }
                        .disabled(viewModel.editBetName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .alert("Complete Challenge", isPresented: $showingCompleteConfirmation) {
            if currentLeaderId != nil {
                Button("Confirm", role: .none) {
                    completeWithCurrentLeader()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let leaderName = currentLeaderName {
                Text("\(leaderName) is the current leader and will be declared the winner. This will settle into the trip results.")
            } else {
                Text("No leader can be determined — scores may be tied or missing. Use \"Declare Winner\" from the menu to pick manually.")
            }
        }
    }

    // MARK: - Helpers

    /// The current leader from live standings (if any single leader exists).
    private var currentLeaderId: UUID? {
        let standings = viewModel.liveStandings(for: bet)
        let leaders = standings.filter(\.isLeader)
        return leaders.count == 1 ? leaders.first?.playerId : nil
    }

    /// Display name of the current leader, or nil if tied/no data.
    private var currentLeaderName: String? {
        guard let leaderId = currentLeaderId else { return nil }
        return viewModel.currentTrip?.player(withId: leaderId)?.name
    }

    /// Complete the challenge with the current leader as winner.
    private func completeWithCurrentLeader() {
        if let leaderId = currentLeaderId {
            viewModel.completeBetWithWinner(betId: bet.id, winnerId: leaderId)
        }
    }

    private var metricHeaderLabel: String {
        switch bet.challengeType {
        case .lowRound, .headToHeadRound:
            return bet.useNetScoring ? "NET SCORES" : "GROSS SCORES"
        case .mostBirdies:
            return bet.useNetScoring ? "BIRDIES (NET)" : "BIRDIES (GROSS)"
        case .fewestPutts:
            return "TOTAL PUTTS"
        case .fewest3Putts:
            return "3-PUTT COUNT"
        case .most3Putts:
            return "3-PUTT COUNT"
        case .custom:
            let name = bet.customMetricName.trimmingCharacters(in: .whitespaces)
            return name.isEmpty ? "CUSTOM" : name.uppercased()
        default:
            return "STANDINGS"
        }
    }
}

// MARK: - Custom Value Entry

struct CustomValueEntryView: View {
    let bet: SideBet
    @Bindable var viewModel: ChallengesViewModel
    @State private var editingPlayerId: UUID?
    @State private var editValue: String = ""
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                let metricName = bet.customMetricName.isEmpty ? "Values" : bet.customMetricName
                Text("Enter \(metricName)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(viewModel.betParticipants(for: bet)) { player in
                HStack(spacing: 12) {
                    Circle()
                        .fill(player.avatarColor.color)
                        .frame(width: 26, height: 26)
                        .overlay {
                            Text(player.initials)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    Text(player.name.split(separator: " ").first.map(String.init) ?? player.name)
                        .font(.subheadline)
                        .frame(minWidth: 60, alignment: .leading)

                    Spacer()

                    if editingPlayerId == player.id {
                        HStack(spacing: 8) {
                            TextField("0", text: $editValue)
                                .keyboardType(.decimalPad)
                                .font(.body.bold())
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Theme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.primary, lineWidth: 2)
                                )
                                .focused($isFieldFocused)
                                .onSubmit { saveValue(for: player.id) }

                            Button {
                                saveValue(for: player.id)
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.primary)
                                    .font(.title3)
                            }
                            .accessibilityLabel("Save value for \(player.name)")
                        }
                    } else {
                        Button {
                            editingPlayerId = player.id
                            if let existing = bet.customValues[player.id] {
                                editValue = existing.formatted()
                            } else {
                                editValue = ""
                            }
                            isFieldFocused = true
                        } label: {
                            if let value = bet.customValues[player.id] {
                                Text(value.formatted())
                                    .font(.body.bold())
                                    .foregroundStyle(Theme.primary)
                                    .frame(minWidth: 50)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Theme.primaryLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Text("Tap")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 50)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Theme.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        .accessibilityLabel("Edit value for \(player.name)")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func saveValue(for playerId: UUID) {
        if let value = Double(editValue) {
            viewModel.updateCustomValue(betId: bet.id, playerId: playerId, value: value)
        }
        editingPlayerId = nil
        editValue = ""
        isFieldFocused = false
    }
}

// MARK: - Winner Picker Sheet

struct BetWinnerPickerSheet: View {
    let bet: SideBet
    @Bindable var viewModel: ChallengesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWinnerId: UUID?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(bet.name)
                        .font(.title3.bold())

                    if bet.isPotBet && bet.potAmount > 0 {
                        Text(bet.potDisplayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Commitment: \(bet.stake)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let roundName = bet.roundDisplayName {
                        Text(roundName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()

                Divider()

                List {
                    Section("Select the Winner") {
                        ForEach(viewModel.betParticipants(for: bet)) { player in
                            Button {
                                selectedWinnerId = player.id
                            } label: {
                                HStack {
                                    Text(player.initials)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(player.avatarColor.color)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(player.name)
                                            .foregroundStyle(.primary)

                                        if let round = bet.round,
                                           let card = round.scorecard(forPlayer: player.id) {
                                            let score = bet.useNetScoring ? card.totalNet : card.totalGross
                                            Text("\(score) (\(bet.useNetScoring ? "Net" : "Gross"))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if selectedWinnerId == player.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.primary)
                                            .font(.title3)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(.secondary)
                                            .font(.title3)
                                    }
                                }
                            }
                        }
                    }

                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Group {
                                if bet.isPotBet && bet.potAmount > 0 {
                                    Text("Winner takes the \(String(format: "%.0f", bet.totalPool)) pt pool. This will appear in Settlement.")
                                } else {
                                    Text("Winner gets \(bet.stake.isEmpty ? "bragging rights" : bet.stake). This will appear in Settlement.")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Declare Winner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if let winnerId = selectedWinnerId {
                            viewModel.completeBetWithWinner(betId: bet.id, winnerId: winnerId)
                        }
                        dismiss()
                    }
                    .disabled(selectedWinnerId == nil)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    let appState = SampleData.makeAppState()
    let vm = ChallengesViewModel(appState: appState)
    let players = SampleData.playersWithTeams
    let bet = SideBet(
        name: "Low Round",
        betType: .lowRound,
        participants: players.map(\.id),
        stake: "Bragging Rights",
        round: SampleData.round
    )
    List {
        SideBetCardView(bet: bet, viewModel: vm)
    }
}

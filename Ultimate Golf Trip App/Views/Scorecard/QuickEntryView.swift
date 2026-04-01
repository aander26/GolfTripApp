import SwiftUI

struct QuickEntryView: View {
    @Bindable var viewModel: ScorecardViewModel
    let round: Round
    let course: Course
    let players: [Player]

    @State private var currentPlayerIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var showPuttsRow = false
    @State private var pendingStrokes: Int = 0
    @State private var lastThreshold: Int = 0
    @State private var showMorePutts = false

    private let hapticLight = UIImpactFeedbackGenerator(style: .light)
    private let hapticMedium = UIImpactFeedbackGenerator(style: .medium)

    private var currentHoleInfo: Hole? {
        course.holes.first { $0.number == viewModel.currentHole }
    }

    private var currentPlayer: Player? {
        guard currentPlayerIndex < players.count else { return nil }
        return players[currentPlayerIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hole header
            holeHeader

            // Hole info
            if let hole = currentHoleInfo {
                holeInfoBar(hole: hole)
            }

            Spacer()

            if allPlayersScored {
                allScoredState
            } else if showPuttsRow {
                puttsSelection
            } else {
                swipeArea
            }

            Spacer()

            // Player progress (tappable) + undo button
            playerProgressBar
            totalsBar
            navigationBar
        }
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.2), value: showPuttsRow)
        .animation(.easeInOut(duration: 0.2), value: currentPlayerIndex)
        .onChange(of: viewModel.currentHole) { _, _ in
            resetForNewHole()
        }
        .sheet(isPresented: $viewModel.showingRoundComplete) {
            RoundCompleteSheet(viewModel: viewModel, round: round, course: course, players: players)
        }
    }

    /// Whether all players already have scores on the current hole
    private var allPlayersScored: Bool {
        players.allSatisfy { hasScore(for: $0) }
    }

    // MARK: - All Scored State

    private var allScoredState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.primary)

            Text("All players scored")
                .font(.title3.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Tap a player dot above to edit, or advance to the next hole.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if viewModel.currentHole < viewModel.holeCount {
                Button {
                    viewModel.currentHole += 1
                } label: {
                    Label("Next Hole", systemImage: "arrow.right")
                }
                .buttonStyle(BoldPrimaryButtonStyle())
                .padding(.top, 8)
            } else {
                Button {
                    viewModel.showingRoundComplete = true
                } label: {
                    Label("Finish Round", systemImage: "flag.checkered")
                }
                .buttonStyle(BoldPrimaryButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Hole Header

    private var holeHeader: some View {
        HStack {
            Button {
                viewModel.previousHole()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
            }
            .disabled(viewModel.currentHole <= 1)

            Spacer()

            VStack(spacing: 2) {
                Text("Hole \(viewModel.currentHole)")
                    .font(.title2.bold())
                if viewModel.currentHole == 10 {
                    Text("Back Nine")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer()

            Button {
                viewModel.nextHole()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
            }
            .disabled(viewModel.currentHole >= course.holes.count)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    // MARK: - Hole Info

    private func holeInfoBar(hole: Hole) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("PAR").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text("\(hole.par)").font(.title3.bold())
            }
            VStack(spacing: 2) {
                Text("YARDS").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text("\(hole.yardage)").font(.title3.bold())
            }
            VStack(spacing: 2) {
                Text("HDCP").font(.caption2).foregroundStyle(Theme.textSecondary)
                Text("\(hole.handicapRating)").font(.title3.bold())
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.primaryMuted)
    }

    // MARK: - Swipe Area

    @ViewBuilder
    private var swipeArea: some View {
        if let player = currentPlayer, let hole = currentHoleInfo {
            VStack(spacing: 16) {
                // Player name + avatar
                HStack(spacing: 10) {
                    Circle()
                        .fill(player.avatarColor.color)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(player.initials)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    Text(player.name)
                        .font(.title3.bold())
                        .foregroundStyle(Theme.textPrimary)

                    // Show existing score badge if editing
                    if let existing = viewModel.scoreForPlayer(player.id, roundId: round.id, holeNumber: viewModel.currentHole),
                       existing.isCompleted {
                        Text("(\(existing.strokes))")
                            .font(.caption.bold())
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primaryMuted)
                            .clipShape(Capsule())
                    }
                }

                // Swipe card
                QuickEntryPlayerCard(
                    player: player,
                    par: hole.par,
                    dragOffset: dragOffset,
                    isDragging: isDragging
                )
                .offset(y: isDragging ? dragOffset * 0.15 : 0)
                .gesture(
                    DragGesture(minimumDistance: 10)
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.height

                            // Haptic at threshold crossings
                            let currentThreshold = Int((dragOffset / QuickEntryPlayerCard.thresholdPerStroke).rounded())
                            if currentThreshold != lastThreshold {
                                lastThreshold = currentThreshold
                                hapticLight.impactOccurred()
                            }
                        }
                        .onEnded { _ in
                            commitScore(hole: hole)
                        }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)

                // Score scale indicator
                scoreScaleIndicator
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Score Scale Indicator

    private var scoreScaleIndicator: some View {
        HStack(spacing: 0) {
            ForEach(-2...3, id: \.self) { offset in
                let label = scaleLabel(for: offset)
                let isActive = isDragging && scoreFromCurrentDrag == offset

                Text(label)
                    .font(.caption2.weight(isActive ? .bold : .regular))
                    .foregroundStyle(isActive ? scaleColor(for: offset) : Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isActive)
            }
        }
        .padding(.horizontal, 16)
    }

    private var scoreFromCurrentDrag: Int {
        let raw = dragOffset / QuickEntryPlayerCard.thresholdPerStroke
        return max(-3, min(6, Int(raw.rounded())))
    }

    private func scaleLabel(for offset: Int) -> String {
        switch offset {
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Dbl"
        case 3: return "Trpl"
        default: return ""
        }
    }

    private func scaleColor(for offset: Int) -> Color {
        switch offset {
        case ...(-2): return .eagle
        case -1: return .birdie
        case 0: return Theme.textPrimary
        case 1: return .bogey
        default: return .doubleBogey
        }
    }

    // MARK: - Putts Selection

    private var puttsSelection: some View {
        VStack(spacing: 16) {
            if let player = currentPlayer {
                HStack(spacing: 10) {
                    Circle()
                        .fill(player.avatarColor.color)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Text(player.initials)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                    Text(player.name)
                        .font(.title3.bold())
                }
            }

            VStack(spacing: 4) {
                Text("Putts?")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("\(pendingStrokes) strokes")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if showMorePutts {
                // Extended putts range for high-stroke holes
                let maxPutts = min(pendingStrokes, 8)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(0...maxPutts, id: \.self) { puttCount in
                        puttButton(puttCount)
                    }
                }
                .padding(.horizontal, 8)
            } else {
                HStack(spacing: 16) {
                    ForEach(0...min(pendingStrokes, 3), id: \.self) { puttCount in
                        puttButton(puttCount)
                    }

                    // Show "More" button if strokes > 3
                    if pendingStrokes > 3 {
                        Button {
                            showMorePutts = true
                        } label: {
                            Text("...")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 64, height: 64)
                                .background(Theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Theme.border, lineWidth: 2)
                                )
                        }
                    }
                }
            }

            Button("Skip") {
                commitPutts(0)
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func puttButton(_ count: Int) -> some View {
        Button {
            commitPutts(count)
        } label: {
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 44, minHeight: 44)
                .frame(width: 64, height: 64)
                .contentShape(Rectangle())
                .background(Theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.border, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
        }
    }

    // MARK: - Player Progress (Tappable)

    private var playerProgressBar: some View {
        HStack(spacing: 6) {
            // Undo / previous player button
            Button {
                goToPreviousPlayer()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.caption2.bold())
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 24)
                    .background(Theme.cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            }
            .disabled(currentPlayerIndex == 0 && !showPuttsRow)

            Spacer()

            // Player dots — tappable to jump to a specific player
            ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                let scored = hasScore(for: player)
                Button {
                    jumpToPlayer(index)
                } label: {
                    Circle()
                        .fill(index == currentPlayerIndex ? player.avatarColor.color : (scored ? Theme.primary : Theme.border))
                        .frame(width: index == currentPlayerIndex ? 14 : 10, height: index == currentPlayerIndex ? 14 : 10)
                        .overlay {
                            if scored && index != currentPlayerIndex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .accessibilityLabel("\(player.name)\(scored ? ", scored" : "")\(index == currentPlayerIndex ? ", current" : "")")
            }

            Spacer()

            // Spacer to balance the undo button
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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
                            .foregroundStyle(Theme.textSecondary)
                        HStack(spacing: 4) {
                            Text("\(totals.gross)")
                                .font(.subheadline.weight(.semibold))
                            if totals.net != totals.gross {
                                Text("(\(totals.net))")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Theme.cardBackground)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(1...max(course.holes.count, 1)), id: \.self) { hole in
                    Button {
                        viewModel.goToHole(hole)
                    } label: {
                        Text("\(hole)")
                            .font(.caption)
                            .fontWeight(viewModel.currentHole == hole ? .bold : .regular)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(viewModel.currentHole == hole ? Theme.primary : Theme.background)
                            )
                            .foregroundStyle(viewModel.currentHole == hole ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    // MARK: - Actions

    private func commitScore(hole: Hole) {
        let scoreToPar = scoreFromCurrentDrag
        let strokes = max(1, hole.par + scoreToPar)

        hapticMedium.impactOccurred()

        // Reset drag state
        isDragging = false
        dragOffset = 0
        lastThreshold = 0

        pendingStrokes = strokes
        showPuttsRow = true
        showMorePutts = false
    }

    private func commitPutts(_ putts: Int) {
        guard let player = currentPlayer else { return }

        viewModel.updateScore(
            roundId: round.id,
            playerId: player.id,
            holeNumber: viewModel.currentHole,
            strokes: pendingStrokes,
            putts: putts
        )

        showPuttsRow = false
        showMorePutts = false
        advanceToNextPlayer()
    }

    private func advanceToNextPlayer() {
        // Find the next unscored player after the current index
        let nextUnscored = findNextUnscoredPlayer(after: currentPlayerIndex)
        if let next = nextUnscored {
            currentPlayerIndex = next
        } else {
            // All players scored on this hole — show the "all scored" state
            // Don't auto-advance; let the user confirm or tap dots to edit
        }
    }

    /// Finds the next player without a score, searching forward from the given index (wrapping).
    /// Pass -1 to search from the very beginning.
    private func findNextUnscoredPlayer(after index: Int) -> Int? {
        let startIndex = max(0, index + 1)
        // Look forward from start position
        for i in startIndex..<players.count {
            if !hasScore(for: players[i]) {
                return i
            }
        }
        // Wrap around from the beginning (only if we didn't start at 0)
        if startIndex > 0 {
            for i in 0..<startIndex {
                if !hasScore(for: players[i]) {
                    return i
                }
            }
        }
        return nil
    }

    private func goToPreviousPlayer() {
        if showPuttsRow {
            // Cancel the putts step, go back to swipe
            showPuttsRow = false
            showMorePutts = false
        } else if currentPlayerIndex > 0 {
            currentPlayerIndex -= 1
        }
    }

    private func jumpToPlayer(_ index: Int) {
        showPuttsRow = false
        showMorePutts = false
        dragOffset = 0
        isDragging = false
        currentPlayerIndex = index
    }

    private func resetForNewHole() {
        showPuttsRow = false
        showMorePutts = false
        dragOffset = 0
        isDragging = false

        // Start at the first unscored player (skip already-scored ones)
        if let firstUnscored = findNextUnscoredPlayer(after: -1) {
            currentPlayerIndex = firstUnscored
        } else {
            currentPlayerIndex = 0
        }
    }

    private func hasScore(for player: Player) -> Bool {
        let score = viewModel.scoreForPlayer(player.id, roundId: round.id, holeNumber: viewModel.currentHole)
        return score?.isCompleted ?? false
    }
}

#Preview {
    QuickEntryView(
        viewModel: SampleData.makeScorecardViewModel(),
        round: SampleData.round,
        course: SampleData.course,
        players: SampleData.playersWithTeams
    )
}

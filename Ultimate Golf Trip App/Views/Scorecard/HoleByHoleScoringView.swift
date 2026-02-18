import SwiftUI

struct HoleByHoleScoringView: View {
    @Bindable var viewModel: ScorecardViewModel
    let round: Round
    let course: Course
    let players: [Player]

    var currentHoleInfo: Hole? {
        course.holes.first { $0.number == viewModel.currentHole }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Hole Navigation Header
            holeHeader

            // Hole Info
            if let hole = currentHoleInfo {
                holeInfoBar(hole: hole)
            }

            // Player Scores
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(players) { player in
                        PlayerScoreCard(
                            player: player,
                            holeNumber: viewModel.currentHole,
                            score: viewModel.scoreForPlayer(player.id, roundId: round.id, holeNumber: viewModel.currentHole),
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
            .accessibilityLabel("Hole \(viewModel.currentHole) of 18")

            Spacer()

            Button {
                viewModel.nextHole()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .disabled(viewModel.currentHole >= 18)
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
                    ForEach(1...18, id: \.self) { hole in
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
                    Text(player.name)
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
                        }
                        .accessibilityLabel("Decrease strokes")
                        .accessibilityHint("Current strokes: \(strokes)")

                        Text("\(strokes)")
                            .font(.system(size: 36, weight: .bold))
                            .frame(minWidth: 50)
                            .accessibilityLabel("\(strokes) strokes")

                        Button {
                            strokes += 1
                            onScoreChanged(strokes, putts)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                        }
                        .accessibilityLabel("Increase strokes")
                        .accessibilityHint("Current strokes: \(strokes)")
                    }
                }

                Divider()
                    .frame(height: 50)

                VStack(spacing: 4) {
                    Text("PUTTS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

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
                        }
                        .accessibilityLabel("Decrease putts")
                        .accessibilityHint("Current putts: \(putts)")

                        Text("\(putts)")
                            .font(.system(size: 36, weight: .bold))
                            .frame(minWidth: 50)
                            .accessibilityLabel("\(putts) putts")

                        Button {
                            putts += 1
                            onScoreChanged(strokes, putts)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.primary)
                        }
                        .accessibilityLabel("Increase putts")
                        .accessibilityHint("Current putts: \(putts)")
                    }
                }
            }
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

#Preview {
    HoleByHoleScoringView(
        viewModel: SampleData.makeScorecardViewModel(),
        round: SampleData.round,
        course: SampleData.course,
        players: SampleData.playersWithTeams
    )
}

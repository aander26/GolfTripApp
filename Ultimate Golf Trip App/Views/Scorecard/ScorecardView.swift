import SwiftUI

struct ScorecardView: View {
    @Bindable var viewModel: ScorecardViewModel
    @State private var quickEntryMode = false
    @State private var showingDeleteConfirmation = false
    @State private var roundToDelete: Round?
    @State private var showingRoundSummary = false

    var body: some View {
        NavigationStack {
            Group {
                if let round = viewModel.currentRound,
                   let trip = viewModel.currentTrip,
                   let course = round.course {
                    let roundPlayers = trip.players.filter { round.playerIds.contains($0.id) }
                    if round.isComplete {
                        // Completed rounds: read-only scorecard
                        HoleByHoleScoringView(
                            viewModel: viewModel,
                            round: round,
                            course: course,
                            players: roundPlayers,
                            isReadOnly: true
                        )
                    } else if quickEntryMode {
                        QuickEntryView(
                            viewModel: viewModel,
                            round: round,
                            course: course,
                            players: roundPlayers
                        )
                    } else {
                        HoleByHoleScoringView(
                            viewModel: viewModel,
                            round: round,
                            course: course,
                            players: roundPlayers
                        )
                    }
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
                        // In-progress round: show editing controls
                        ToolbarItem(placement: .secondaryAction) {
                            Button {
                                quickEntryMode.toggle()
                            } label: {
                                Image(systemName: quickEntryMode ? "bolt.fill" : "bolt")
                                    .foregroundStyle(quickEntryMode ? Theme.primary : Theme.textSecondary)
                            }
                            .accessibilityLabel(quickEntryMode ? "Switch to standard entry" : "Switch to quick entry")
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
            Section("Rounds") {
                ForEach(trip.rounds) { round in
                    let courseName = round.course?.name ?? "Unknown"
                    Button {
                        viewModel.selectRound(round)
                    } label: {
                        HStack {
                            RoundRowView(round: round, courseName: courseName)
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
        .themedList()
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

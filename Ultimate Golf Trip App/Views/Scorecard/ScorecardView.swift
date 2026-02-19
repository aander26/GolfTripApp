import SwiftUI

struct ScorecardView: View {
    @Bindable var viewModel: ScorecardViewModel

    var body: some View {
        NavigationStack {
            Group {
                if let round = viewModel.currentRound,
                   let trip = viewModel.currentTrip,
                   let course = round.course {
                    HoleByHoleScoringView(
                        viewModel: viewModel,
                        round: round,
                        course: course,
                        players: trip.players.filter { round.playerIds.contains($0.id) }
                    )
                } else if let trip = viewModel.currentTrip, !trip.rounds.isEmpty {
                    roundsList(trip: trip)
                } else {
                    noRoundsView
                }
            }
            .navigationTitle("Scorecard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingRoundSetup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Start new round")
                }
            }
            .sheet(isPresented: $viewModel.showingRoundSetup) {
                RoundSetupView(viewModel: viewModel)
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
                        RoundRowView(round: round, courseName: courseName)
                    }
                }
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

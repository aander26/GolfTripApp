import SwiftUI

struct TeamAssignmentView: View {
    @Bindable var viewModel: TripViewModel

    var body: some View {
        List {
            if let trip = viewModel.currentTrip {
                // Unassigned Players
                let unassigned = trip.players.filter { $0.teamId == nil }
                if !unassigned.isEmpty {
                    Section("Unassigned") {
                        ForEach(unassigned) { player in
                            playerRow(player: player, trip: trip)
                        }
                    }
                }

                // Players per team
                ForEach(trip.teams) { team in
                    Section {
                        ForEach(trip.playersOnTeam(team.id)) { player in
                            playerRow(player: player, trip: trip)
                        }

                        if trip.playersOnTeam(team.id).isEmpty {
                            Text("No players assigned")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        HStack {
                            Circle()
                                .fill(team.color.color)
                                .frame(width: 10, height: 10)
                            Text(team.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Assign Teams")
    }

    private func playerRow(player: Player, trip: Trip) -> some View {
        HStack {
            Circle()
                .fill(player.avatarColor.color)
                .frame(width: 28, height: 28)
                .overlay {
                    Text(player.initials)
                        .font(.system(size: 10))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }

            Text(player.name)
                .font(.body)

            Spacer()

            Menu {
                Button("No Team") {
                    viewModel.assignPlayerToTeam(player, team: nil)
                }
                ForEach(trip.teams) { team in
                    Button {
                        viewModel.assignPlayerToTeam(player, team: team)
                    } label: {
                        Label(team.name, systemImage: player.teamId == team.id ? "checkmark" : "")
                    }
                }
            } label: {
                if let teamId = player.teamId, let team = trip.team(withId: teamId) {
                    Text(team.name)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(team.color.color.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Text("Assign")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TeamAssignmentView(viewModel: SampleData.makeTripViewModel())
    }
}

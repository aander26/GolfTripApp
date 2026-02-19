import SwiftUI

struct TripListView: View {
    @Bindable var viewModel: TripViewModel
    @Environment(AppState.self) private var appState
    @State private var showingCreate = false
    @State private var showingJoin = false
    @State private var tripToDelete: Trip?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationTitle("Golf Trips")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingCreate = true
                        } label: {
                            Label("Create Trip", systemImage: "plus.circle")
                        }
                        Button {
                            showingJoin = true
                        } label: {
                            Label("Join Trip", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create or join trip")
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateTripView(viewModel: viewModel, isPresented: $showingCreate)
            }
            .sheet(isPresented: $showingJoin) {
                JoinTripView(viewModel: viewModel, isPresented: $showingJoin)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.golf")
                .font(.system(size: 80))
                .foregroundStyle(Theme.primary)

            Text("No Trips Yet")
                .font(.title)
                .fontWeight(.bold)

            Text("Create your first golf trip to start tracking scores, leaderboards, and side games with your buddies.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingCreate = true
            } label: {
                Label("Create Trip", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(BoldPrimaryButtonStyle())

            Button {
                showingJoin = true
            } label: {
                Label("Join a Trip", systemImage: "person.badge.plus")
                    .font(.subheadline)
            }
            .foregroundStyle(Theme.primary)

            Spacer()
        }
    }

    private var tripList: some View {
        List {
            ForEach(viewModel.trips) { trip in
                Button {
                    viewModel.selectTrip(trip)
                } label: {
                    TripRowView(trip: trip)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if trip.isOwner(appState.currentUser?.id) {
                        Button(role: .destructive) {
                            tripToDelete = trip
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            tripToDelete = trip
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Leave", systemImage: "arrow.right.square")
                        }
                    }
                }
            }
            .alert("Are you sure?", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    tripToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let trip = tripToDelete {
                        if trip.isOwner(appState.currentUser?.id) {
                            viewModel.deleteTrip(trip)
                        } else {
                            viewModel.leaveTrip(trip)
                        }
                    }
                    tripToDelete = nil
                }
            } message: {
                if let trip = tripToDelete {
                    if trip.isOwner(appState.currentUser?.id) {
                        Text("This will permanently delete \"\(trip.name)\" and all its data.")
                    } else {
                        Text("You will be removed from \"\(trip.name)\".")
                    }
                }
            }
        }
    }
}

struct TripRowView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trip.name)
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 16) {
                Label(trip.dateRange, systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label("\(trip.players.count) players", systemImage: "person.2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Label("\(trip.rounds.count) rounds", systemImage: "flag.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(trip.name), \(trip.dateRange), \(trip.players.count) players, \(trip.rounds.count) rounds")
    }
}

#Preview("With Trips") {
    TripListView(viewModel: SampleData.makeTripViewModel())
        .environment(SampleData.makeAppState())
}

#Preview("Empty") {
    TripListView(viewModel: SampleData.makeTripViewModel(appState: SampleData.makeEmptyAppState()))
        .environment(SampleData.makeEmptyAppState())
}

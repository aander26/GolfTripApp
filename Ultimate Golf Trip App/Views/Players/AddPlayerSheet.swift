import SwiftUI

struct AddPlayerSheet: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Player Info") {
                    TextField("Name", text: $viewModel.newPlayerName)
                        .textInputAutocapitalization(.words)

                    TextField("Handicap Index", text: $viewModel.newPlayerHandicap)
                        .keyboardType(.decimalPad)
                }

                Section("Avatar Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(PlayerColor.allCases) { color in
                            Circle()
                                .fill(color.color)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if viewModel.newPlayerColor == color {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                                .onTapGesture {
                                    viewModel.newPlayerColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                if let trip = viewModel.currentTrip, !trip.teams.isEmpty {
                    Section("Team Assignment") {
                        Picker("Team", selection: $viewModel.newPlayerTeamId) {
                            Text("No Team").tag(UUID?.none)
                            ForEach(trip.teams) { team in
                                HStack {
                                    Circle()
                                        .fill(team.color.color)
                                        .frame(width: 12, height: 12)
                                    Text(team.name)
                                }
                                .tag(Optional(team.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addPlayer()
                        dismiss()
                    }
                    .disabled(viewModel.newPlayerName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AddTeamSheet: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Team Info") {
                    TextField("Team Name", text: $viewModel.newTeamName)
                        .textInputAutocapitalization(.words)
                }

                Section("Team Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(TeamColor.allCases) { color in
                            HStack {
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 30, height: 30)
                                Text(color.rawValue)
                                    .font(.subheadline)
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.newTeamColor == color ? color.color : .clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                viewModel.newTeamColor = color
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addTeam()
                        dismiss()
                    }
                    .disabled(viewModel.newTeamName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AddCourseSheet: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingHoleSetup = false
    @State private var tempCourse: Course?

    var body: some View {
        NavigationStack {
            Form {
                Section("Course Info") {
                    TextField("Course Name", text: $viewModel.newCourseName)
                        .textInputAutocapitalization(.words)

                    TextField("City", text: $viewModel.newCourseCity)
                        .textInputAutocapitalization(.words)

                    TextField("State", text: $viewModel.newCourseState)
                        .textInputAutocapitalization(.characters)
                }

                Section("Ratings") {
                    HStack {
                        Text("Slope Rating")
                        Spacer()
                        TextField("113", text: $viewModel.newCourseSlopeRating)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("Course Rating")
                        Spacer()
                        TextField("72.0", text: $viewModel.newCourseCourseRating)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section {
                    Text("You can customize individual hole par, yardage, and handicap ratings after adding the course.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addCourse()
                        dismiss()
                    }
                    .disabled(viewModel.newCourseName.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview("Add Player") {
    AddPlayerSheet(viewModel: SampleData.makeTripViewModel())
}

#Preview("Add Team") {
    AddTeamSheet(viewModel: SampleData.makeTripViewModel())
}

#Preview("Add Course") {
    AddCourseSheet(viewModel: SampleData.makeTripViewModel())
}

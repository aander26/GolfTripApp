import SwiftUI
import MapKit

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
    @State private var searchService = GolfCourseSearchService()
    @State private var showingSuggestions = false

    var body: some View {
        NavigationStack {
            Form {
                // Search Section
                Section("Search for a Course") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Type course name...", text: $searchService.searchText)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: searchService.searchText) {
                                showingSuggestions = !searchService.suggestions.isEmpty
                            }
                    }

                    if searchService.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Looking up course...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Suggestions
                if showingSuggestions && !searchService.suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(searchService.suggestions, id: \.hashValue) { completion in
                            Button {
                                Task {
                                    await searchService.selectSuggestion(completion)
                                    applySearchResult()
                                    showingSuggestions = false
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(completion.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Auto-fill Status
                if let result = searchService.selectedResult {
                    Section {
                        if result.hasDetailedData {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Full course data found!")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let data = result.courseData {
                                        Text("Par \(data.totalPar) \u{00B7} \(data.totalYardage) yards \u{00B7} 18 holes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            } icon: {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        } else {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Location found")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Hole details will use defaults \u{2014} customize after adding")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "location.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // Course Info (editable, auto-filled from search)
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

                if searchService.selectedResult == nil {
                    Section {
                        Text("Tip: Search above to auto-fill course data, or enter details manually.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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

    /// Apply search result to the view model's form fields.
    private func applySearchResult() {
        guard let result = searchService.selectedResult else { return }

        viewModel.newCourseName = result.name
        viewModel.newCourseCity = result.city
        viewModel.newCourseState = result.state
        viewModel.newCourseLatitude = result.latitude
        viewModel.newCourseLongitude = result.longitude

        if let data = result.courseData {
            viewModel.newCourseSlopeRating = String(format: "%.0f", data.slopeRating)
            viewModel.newCourseCourseRating = String(format: "%.1f", data.courseRating)
            viewModel.matchedCourseData = data
        } else {
            viewModel.matchedCourseData = nil
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

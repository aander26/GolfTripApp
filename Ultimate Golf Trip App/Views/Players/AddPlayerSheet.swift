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

// MARK: - Edit Player Sheet

struct EditPlayerSheet: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if viewModel.editingPlayer != nil {
                Form {
                    Section("Player Info") {
                        TextField("Name", text: $viewModel.editPlayerName)
                            .textInputAutocapitalization(.words)

                        TextField("Handicap Index", text: $viewModel.editPlayerHandicap)
                            .keyboardType(.decimalPad)
                    }

                    Section("Avatar Color") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                            ForEach(PlayerColor.allCases) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if viewModel.editPlayerColor == color {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .onTapGesture {
                                        viewModel.editPlayerColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    if let trip = viewModel.currentTrip, !trip.teams.isEmpty {
                        Section("Team Assignment") {
                            Picker("Team", selection: $viewModel.editPlayerTeamId) {
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
                .navigationTitle("Edit Player")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.savePlayerEdits()
                            dismiss()
                        }
                        .disabled(viewModel.editPlayerName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            } else {
                ContentUnavailableView("Player not found", systemImage: "person.slash")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
            }
        }
    }
}

// MARK: - Edit Team Sheet

struct EditTeamSheet: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if viewModel.editingTeam != nil {
                Form {
                    Section("Team Info") {
                        TextField("Team Name", text: $viewModel.editTeamName)
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
                                        .stroke(viewModel.editTeamColor == color ? color.color : .clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    viewModel.editTeamColor = color
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Show players on this team (read-only info)
                    if let team = viewModel.editingTeam, !team.players.isEmpty {
                        Section("Players on Team") {
                            ForEach(team.players) { player in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(player.avatarColor.color)
                                        .frame(width: 24, height: 24)
                                        .overlay {
                                            Text(player.initials)
                                                .font(.system(size: 9))
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                        }
                                    Text(player.name)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Edit Team")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.saveTeamEdits()
                            dismiss()
                        }
                        .disabled(viewModel.editTeamName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            } else {
                ContentUnavailableView("Team not found", systemImage: "person.3.slash")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
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
                                showingSuggestions = !searchService.suggestions.isEmpty || !searchService.databaseMatches.isEmpty
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

                // MapKit Suggestions
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

                // Database Matches (shown when bundled database has results)
                if showingSuggestions && !searchService.databaseMatches.isEmpty && searchService.selectedResult == nil {
                    Section("From Course Database") {
                        ForEach(searchService.databaseMatches, id: \.id) { course in
                            Button {
                                showingSuggestions = false
                                Task {
                                    await searchService.selectDatabaseCourse(course)
                                    applySearchResult()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        Text("\(course.city), \(course.state)")
                                        Text("Par \(course.totalPar)")
                                        Text("\(course.totalYardage) yds")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

                // Tee Box Selection (only when course data is matched)
                if !viewModel.availableTeeBoxes.isEmpty {
                    Section {
                        ForEach(viewModel.availableTeeBoxes) { teeBox in
                            Button {
                                viewModel.selectedTeeBoxName = teeBox.name
                                // Auto-fill slope and rating from selected tee
                                viewModel.newCourseSlopeRating = String(format: "%.0f", teeBox.slopeRating)
                                viewModel.newCourseCourseRating = String(format: "%.1f", teeBox.courseRating)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(teeBoxColor(teeBox.color))
                                        .frame(width: 14, height: 14)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(teeBox.name)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        Text("\(teeBox.totalYardage) yds \u{00B7} Slope \(Int(teeBox.slopeRating)) \u{00B7} Rating \(String(format: "%.1f", teeBox.courseRating))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if viewModel.selectedTeeBoxName == teeBox.name {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.primary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Select Tee Box")
                    } footer: {
                        Text("Choose your tees to set the correct slope and course rating for accurate handicap calculations.")
                    }
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
            // Generate tee box options
            viewModel.availableTeeBoxes = GolfCourseDatabase.shared.teeBoxes(for: data)
            // Auto-select "Back" tees (the championship data from JSON)
            viewModel.selectedTeeBoxName = "Back"
        } else {
            viewModel.matchedCourseData = nil
            viewModel.availableTeeBoxes = []
            viewModel.selectedTeeBoxName = nil
        }
    }

    private func teeBoxColor(_ color: String) -> Color {
        switch color.lowercased() {
        case "black": return .black
        case "blue": return .blue
        case "white": return Color(white: 0.85)
        case "gold", "yellow": return .yellow
        case "red": return .red
        case "green": return .green
        default: return .gray
        }
    }
}

// MARK: - Edit Course Sheet

struct EditCourseSheet: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let course = viewModel.editingCourse {
                Form {
                    Section("Course Info") {
                        TextField("Course Name", text: $viewModel.newCourseName)
                            .textInputAutocapitalization(.words)

                        TextField("City", text: $viewModel.newCourseCity)
                            .textInputAutocapitalization(.words)

                        TextField("State", text: $viewModel.newCourseState)
                            .textInputAutocapitalization(.characters)
                    }

                    // Tee Box Selection
                    if !viewModel.availableTeeBoxes.isEmpty {
                        Section {
                            ForEach(viewModel.availableTeeBoxes) { teeBox in
                                Button {
                                    viewModel.selectedTeeBoxName = teeBox.name
                                    viewModel.newCourseSlopeRating = String(format: "%.0f", teeBox.slopeRating)
                                    viewModel.newCourseCourseRating = String(format: "%.1f", teeBox.courseRating)
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(teeBoxDisplayColor(teeBox.color))
                                            .frame(width: 14, height: 14)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(teeBox.name)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text("\(teeBox.totalYardage) yds \u{00B7} Slope \(Int(teeBox.slopeRating)) \u{00B7} Rating \(String(format: "%.1f", teeBox.courseRating))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if viewModel.selectedTeeBoxName == teeBox.name {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(Theme.primary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Tee Box")
                        } footer: {
                            Text("Selecting a tee box updates the slope, course rating, and yardages for accurate handicap calculations.")
                        }
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

                    // Hole-by-hole editing
                    Section {
                        ForEach(Array(course.holes.enumerated()), id: \.offset) { index, hole in
                            HoleEditRow(
                                hole: hole,
                                onUpdate: { par, yardage, handicapRating in
                                    viewModel.updateCourseHole(course, holeIndex: index, par: par, yardage: yardage, handicapRating: handicapRating)
                                }
                            )
                        }
                    } header: {
                        HStack {
                            Text("Holes")
                            Spacer()
                            Text("Par \(course.totalPar) \u{00B7} \(course.totalYardage) yds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Edit Course")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveCourseEdits(course)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            } else {
                ContentUnavailableView("Course not found", systemImage: "flag.slash")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { dismiss() }
                        }
                    }
            }
        }
    }

    private func saveCourseEdits(_ course: Course) {
        course.name = viewModel.newCourseName
        course.city = viewModel.newCourseCity
        course.state = viewModel.newCourseState
        course.slopeRating = Double(viewModel.newCourseSlopeRating) ?? course.slopeRating
        course.courseRating = Double(viewModel.newCourseCourseRating) ?? course.courseRating

        // Apply tee box selection if changed
        if let teeBoxName = viewModel.selectedTeeBoxName,
           let teeBox = viewModel.availableTeeBoxes.first(where: { $0.name == teeBoxName }) {
            course.applyTeeBox(teeBox)
        }

        viewModel.appState.saveContext()
    }

    private func teeBoxDisplayColor(_ color: String) -> Color {
        switch color.lowercased() {
        case "black": return .black
        case "blue": return .blue
        case "white": return Color(white: 0.85)
        case "gold", "yellow": return .yellow
        case "red": return .red
        case "green": return .green
        default: return .gray
        }
    }
}

// MARK: - Hole Edit Row

private struct HoleEditRow: View {
    let hole: Hole
    let onUpdate: (Int, Int, Int) -> Void

    @State private var par: Int
    @State private var yardage: String
    @State private var handicapRating: String

    init(hole: Hole, onUpdate: @escaping (Int, Int, Int) -> Void) {
        self.hole = hole
        self.onUpdate = onUpdate
        _par = State(initialValue: hole.par)
        _yardage = State(initialValue: String(hole.yardage))
        _handicapRating = State(initialValue: String(hole.handicapRating))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(hole.number)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 30, alignment: .leading)

            Picker("Par", selection: $par) {
                Text("3").tag(3)
                Text("4").tag(4)
                Text("5").tag(5)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)
            .onChange(of: par) {
                onUpdate(par, Int(yardage) ?? hole.yardage, Int(handicapRating) ?? hole.handicapRating)
            }

            TextField("Yds", text: $yardage)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 55)
                .onChange(of: yardage) {
                    if let y = Int(yardage) {
                        onUpdate(par, y, Int(handicapRating) ?? hole.handicapRating)
                    }
                }

            Text("HCP")
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField("", text: $handicapRating)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 28)
                .onChange(of: handicapRating) {
                    if let h = Int(handicapRating) {
                        onUpdate(par, Int(yardage) ?? hole.yardage, h)
                    }
                }
        }
        .font(.subheadline)
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

import SwiftUI

struct RoundSetupView: View {
    @Bindable var viewModel: ScorecardViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let trip = viewModel.currentTrip {
                    // Course Selection
                    Section("Course") {
                        if trip.courses.isEmpty {
                            Text("Add a course in the Trip tab first.")
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Select Course", selection: $viewModel.selectedCourseId) {
                                Text("Select a course").tag(UUID?.none)
                                ForEach(trip.courses) { course in
                                    Text("\(course.name) (Par \(course.totalPar))")
                                        .tag(Optional(course.id))
                                }
                            }
                        }
                    }

                    // Format Selection
                    Section("Format") {
                        Picker("Scoring Format", selection: $viewModel.selectedFormat) {
                            ForEach(ScoringFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.navigationLink)

                        Text(viewModel.selectedFormat.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Team Scoring Options (shown for team-based formats when teams exist)
                    if viewModel.selectedFormat.requiresTeams && !trip.teams.isEmpty {
                        Section {
                            Picker("Team Scoring", selection: $viewModel.selectedTeamScoringFormat) {
                                ForEach(TeamScoringFormat.allCases) { format in
                                    Text(format.shortName).tag(format)
                                }
                            }
                            .pickerStyle(.navigationLink)

                            Text(viewModel.selectedTeamScoringFormat.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("Team Competition")
                        }

                        // Points Configuration
                        if viewModel.selectedTeamScoringFormat == .ninesAndOverall {
                            Section("Points (Nines & Overall)") {
                                ninesPointsFields
                                Text("Each 1v1 match scores front 9, back 9, and overall separately. Max 5 pts per match.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Section("Scoring Structure") {
                                Picker("Points Structure", selection: $viewModel.teamUseNinesAndOverall) {
                                    Text("Per Match").tag(false)
                                    Text("Front 9 / Back 9 / Overall").tag(true)
                                }
                                .pickerStyle(.segmented)
                            }

                            if viewModel.teamUseNinesAndOverall {
                                Section("Points (Front 9 / Back 9 / Overall)") {
                                    ninesPointsFields
                                    Text("Points awarded for winning each segment: front 9, back 9, and overall 18.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Section("Points") {
                                    HStack {
                                        Text(viewModel.selectedTeamScoringFormat.pointsLabel + " (Win)")
                                        Spacer()
                                        TextField("1.0", text: $viewModel.teamPointsPerWin)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                    }
                                    HStack {
                                        Text("Halve")
                                        Spacer()
                                        TextField("0.5", text: $viewModel.teamPointsPerHalve)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                    }
                                    HStack {
                                        Text("Loss")
                                        Spacer()
                                        TextField("0.0", text: $viewModel.teamPointsPerLoss)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 50)
                                    }
                                }
                            }
                        }
                    }

                    // Player Selection
                    Section("Players") {
                        if trip.players.isEmpty {
                            Text("Add players in the Trip tab first.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(trip.players) { player in
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

                                    Spacer()

                                    Text(player.formattedHandicap)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: viewModel.selectedPlayerIds.contains(player.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.selectedPlayerIds.contains(player.id) ? Theme.primary : Theme.textSecondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if viewModel.selectedPlayerIds.contains(player.id) {
                                        viewModel.selectedPlayerIds.remove(player.id)
                                    } else {
                                        viewModel.selectedPlayerIds.insert(player.id)
                                    }
                                }
                            }
                        }
                    }

                    // Course Handicap Preview
                    if viewModel.selectedCourseId != nil && !viewModel.selectedPlayerIds.isEmpty {
                        Section("Course Handicaps") {
                            ForEach(trip.players.filter({ viewModel.selectedPlayerIds.contains($0.id) })) { player in
                                if let course = viewModel.selectedCourse {
                                    let ch = HandicapEngine.courseHandicap(
                                        handicapIndex: player.handicapIndex,
                                        slopeRating: course.slopeRating,
                                        courseRating: course.courseRating,
                                        par: course.totalPar
                                    )
                                    HStack {
                                        Text(player.name)
                                        Spacer()
                                        Text("Index: \(player.formattedHandicap)")
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                        Text("Course: \(ch)")
                                            .fontWeight(.semibold)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetRoundSetup()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        viewModel.startNewRound()
                        dismiss()
                    }
                    .disabled(viewModel.selectedCourseId == nil || viewModel.selectedPlayerIds.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Subviews

extension RoundSetupView {
    @ViewBuilder
    var ninesPointsFields: some View {
        HStack {
            Text("Front 9 / Back 9 Win")
            Spacer()
            TextField("1.0", text: $viewModel.teamPointsPerNineWin)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
        HStack {
            Text("Front 9 / Back 9 Halve")
            Spacer()
            TextField("0.5", text: $viewModel.teamPointsPerNineHalve)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
        HStack {
            Text("Overall 18 Win")
            Spacer()
            TextField("3.0", text: $viewModel.teamPointsPerOverallWin)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
        HStack {
            Text("Overall 18 Halve")
            Spacer()
            TextField("1.5", text: $viewModel.teamPointsPerOverallHalve)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 50)
        }
    }
}

#Preview {
    RoundSetupView(viewModel: SampleData.makeScorecardViewModel())
}

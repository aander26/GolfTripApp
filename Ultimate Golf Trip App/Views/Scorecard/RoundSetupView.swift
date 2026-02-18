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

#Preview {
    RoundSetupView(viewModel: SampleData.makeScorecardViewModel())
}

import SwiftUI

struct TripRulesView: View {
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var pointsPerWin: Double
    @State private var pointsPerHalve: Double
    @State private var pointsPerLoss: Double

    init(viewModel: TripViewModel) {
        self.viewModel = viewModel
        let trip = viewModel.currentTrip
        _pointsPerWin = State(initialValue: trip?.pointsPerMatchWin ?? 1.0)
        _pointsPerHalve = State(initialValue: trip?.pointsPerMatchHalve ?? 0.5)
        _pointsPerLoss = State(initialValue: trip?.pointsPerMatchLoss ?? 0.0)
    }

    var body: some View {
        Form {
            // Per-Course Rules
            if let trip = viewModel.currentTrip, !trip.courses.isEmpty {
                Section {
                    ForEach(trip.courses) { course in
                        NavigationLink {
                            CourseScoringRuleView(course: course, viewModel: viewModel)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(course.name)
                                        .font(.body)
                                    if let rule = course.teamScoringRule {
                                        Text(rule.summaryText)
                                            .font(.caption)
                                            .foregroundStyle(Theme.primary)
                                    } else {
                                        Text("Using default rules")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("Course Rules")
                } footer: {
                    Text("Assign a specific scoring format and points for each course. Courses without a custom rule use the default trip rules below.")
                }
            }

            // Default Trip Rules (fallback)
            Section {
                Stepper("Win: \(pointsPerWin, specifier: "%.1f") pts",
                        value: $pointsPerWin, in: 0...10, step: 0.5)

                Stepper("Halve: \(pointsPerHalve, specifier: "%.1f") pts",
                        value: $pointsPerHalve, in: 0...10, step: 0.5)

                Stepper("Loss: \(pointsPerLoss, specifier: "%.1f") pts",
                        value: $pointsPerLoss, in: 0...10, step: 0.5)
            } header: {
                Text("Default Match Play Points")
            } footer: {
                Text("Default points for courses without a custom rule. Traditional match play: each match win/halve/loss awards these points.")
            }

            Section("Presets") {
                Button("Ryder Cup (1 / 0.5 / 0)") {
                    pointsPerWin = 1.0
                    pointsPerHalve = 0.5
                    pointsPerLoss = 0.0
                }
                Button("Winner Take All (1 / 0 / 0)") {
                    pointsPerWin = 1.0
                    pointsPerHalve = 0.0
                    pointsPerLoss = 0.0
                }
                Button("Competitive (3 / 1 / 0)") {
                    pointsPerWin = 3.0
                    pointsPerHalve = 1.0
                    pointsPerLoss = 0.0
                }
            }
        }
        .navigationTitle("Trip Rules")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    viewModel.updateTripRules(
                        pointsPerWin: pointsPerWin,
                        pointsPerHalve: pointsPerHalve,
                        pointsPerLoss: pointsPerLoss
                    )
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Course Scoring Rule View

struct CourseScoringRuleView: View {
    let course: Course
    @Bindable var viewModel: TripViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var useCustomRule: Bool
    @State private var selectedFormat: TeamScoringFormat
    @State private var pointsPerWin: Double
    @State private var pointsPerHalve: Double
    @State private var pointsPerLoss: Double

    init(course: Course, viewModel: TripViewModel) {
        self.course = course
        self.viewModel = viewModel

        let hasRule = course.teamScoringRule != nil
        let rule = course.teamScoringRule ?? TeamScoringRule()
        _useCustomRule = State(initialValue: hasRule)
        _selectedFormat = State(initialValue: rule.format)
        _pointsPerWin = State(initialValue: rule.pointsPerWin)
        _pointsPerHalve = State(initialValue: rule.pointsPerHalve)
        _pointsPerLoss = State(initialValue: rule.pointsPerLoss)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Custom Rule for This Course", isOn: $useCustomRule)
                    .tint(Theme.primary)
            } footer: {
                if !useCustomRule {
                    Text("This course will use the default trip rules (traditional match play).")
                }
            }

            if useCustomRule {
                // Format Picker
                Section("Scoring Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(TeamScoringFormat.allCases) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Text(selectedFormat.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Points Configuration
                Section {
                    Stepper("\(selectedFormat.isPerPlayerFormat ? "Win" : "Winner"): \(pointsPerWin, specifier: "%.1f") pts",
                            value: $pointsPerWin, in: 0...20, step: 0.5)

                    Stepper("Halve/Tie: \(pointsPerHalve, specifier: "%.1f") pts",
                            value: $pointsPerHalve, in: 0...20, step: 0.5)

                    Stepper("Loss: \(pointsPerLoss, specifier: "%.1f") pts",
                            value: $pointsPerLoss, in: 0...20, step: 0.5)
                } header: {
                    Text(selectedFormat.pointsLabel)
                } footer: {
                    pointsFooter
                }

                // Quick Presets
                Section("Quick Presets") {
                    Button("Ryder Cup — Match Play (1 / 0.5 / 0)") {
                        selectedFormat = .traditionalMatchPlay
                        pointsPerWin = 1.0
                        pointsPerHalve = 0.5
                        pointsPerLoss = 0.0
                    }
                    Button("Singles — Point Per Hole Won (1 / 0 / 0)") {
                        selectedFormat = .singlesMatchPlay
                        pointsPerWin = 1.0
                        pointsPerHalve = 0.0
                        pointsPerLoss = 0.0
                    }
                    Button("Team Stroke Play — 5 Points to Winner") {
                        selectedFormat = .teamStrokePlay
                        pointsPerWin = 5.0
                        pointsPerHalve = 2.5
                        pointsPerLoss = 0.0
                    }
                    Button("Best Ball — 3 Points to Winner") {
                        selectedFormat = .teamBestBall
                        pointsPerWin = 3.0
                        pointsPerHalve = 1.5
                        pointsPerLoss = 0.0
                    }
                }
            }
        }
        .navigationTitle(course.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if useCustomRule {
                        let rule = TeamScoringRule(
                            format: selectedFormat,
                            pointsPerWin: pointsPerWin,
                            pointsPerHalve: pointsPerHalve,
                            pointsPerLoss: pointsPerLoss
                        )
                        viewModel.updateCourseScoringRule(course, rule: rule)
                    } else {
                        viewModel.updateCourseScoringRule(course, rule: nil)
                    }
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var pointsFooter: some View {
        switch selectedFormat {
        case .traditionalMatchPlay:
            Text("Each 1v1 match win, halve, or loss awards these points to the team.")
        case .singlesMatchPlay:
            Text("Each individual hole won earns the winning player's team these points.")
        case .teamStrokePlay:
            Text("The team with the lower combined net score wins the defined points.")
        case .teamBestBall:
            Text("The team with the lower best-ball net score wins the defined points.")
        }
    }
}

#Preview {
    NavigationStack {
        TripRulesView(viewModel: SampleData.makeTripViewModel())
    }
}

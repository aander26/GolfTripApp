import SwiftUI

struct SideGamesView: View {
    @Bindable var challengesViewModel: ChallengesViewModel
    @State private var showingSettlement = false

    var body: some View {
        NavigationStack {
            Group {
                if challengesViewModel.activeBets.isEmpty && challengesViewModel.completedBets.isEmpty {
                    emptyState
                } else {
                    challengesList
                }
            }
            .navigationTitle("Challenges")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        challengesViewModel.showingCreateBet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $challengesViewModel.showingCreateBet) {
                CreateSideBetView(viewModel: challengesViewModel)
            }
            .sheet(isPresented: $showingSettlement) {
                NavigationStack {
                    SettlementView(trip: challengesViewModel.currentTrip)
                        .navigationTitle("Trip Settlement")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingSettlement = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Quick Create Templates

    private var singleRoundTemplates: [ChallengeTemplate] {
        ChallengeTemplate.allCases.filter { !$0.isTripWide }
    }

    private var tripWideTemplates: [ChallengeTemplate] {
        ChallengeTemplate.allCases.filter { $0.isTripWide }
    }

    private var quickCreateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Single Round")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(singleRoundTemplates) { template in
                        templateButton(template)
                    }
                }
                .padding(.horizontal)
            }

            Text("Trip-Wide")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(tripWideTemplates) { template in
                        templateButton(template, isTripWide: true)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func templateButton(_ template: ChallengeTemplate, isTripWide: Bool = false) -> some View {
        Button {
            challengesViewModel.applyTemplate(template)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: template.icon)
                    .font(.caption)
                Text(template.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isTripWide ? Color.blue.opacity(0.12) : Theme.primaryLight)
            .foregroundStyle(isTripWide ? .blue : Theme.primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Create \(template.displayName) challenge\(isTripWide ? ", trip-wide" : "")")
    }

    // MARK: - Challenges List

    private var challengesList: some View {
        List {
            Section {
                quickCreateSection
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // Live Results dashboard
            ChallengeResultsSection(viewModel: challengesViewModel)

            if !challengesViewModel.activeBets.isEmpty {
                Section("Active Challenges") {
                    ForEach(challengesViewModel.activeBets) { bet in
                        SideBetCardView(
                            bet: bet,
                            viewModel: challengesViewModel
                        )
                    }
                }
            }

            if !challengesViewModel.completedBets.isEmpty {
                Section("Settled") {
                    ForEach(challengesViewModel.completedBets) { bet in
                        SideBetCardView(
                            bet: bet,
                            viewModel: challengesViewModel
                        )
                    }
                }
            }

            Section {
                settlementButton
            }
        }
        .themedList()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "trophy")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("No Challenges")
                .font(.title2)
                .fontWeight(.bold)

            Text("Create challenges based on round scores.\nWho gets the low round? Head-to-head matchup? You decide.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            quickCreateSection

            Button {
                challengesViewModel.showingCreateBet = true
            } label: {
                Label("Custom Challenge", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(BoldPrimaryButtonStyle())

            settlementButton

            Spacer()
        }
    }

    // MARK: - Settlement Button

    private var settlementButton: some View {
        Button {
            showingSettlement = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.clipboard")
                    .font(.title3)
                    .foregroundStyle(Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("View Trip Settlement")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("See who owes what across all games and challenges")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    let appState = SampleData.makeAppState()
    SideGamesView(
        challengesViewModel: ChallengesViewModel(appState: appState)
    )
}

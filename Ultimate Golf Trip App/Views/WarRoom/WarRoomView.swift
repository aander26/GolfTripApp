import SwiftUI

struct WarRoomView: View {
    @Bindable var viewModel: WarRoomViewModel
    var leaderboardViewModel: LeaderboardViewModel
    var challengesViewModel: ChallengesViewModel
    @Binding var selectedTab: Int
    @Environment(AppState.self) private var appState
    @State private var recapViewModel: DailyRecapViewModel?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.currentTrip != nil {
                        // MARK: - Dashboard Widgets

                        // Next Up with countdown
                        if let nextEvent = viewModel.nextEvent {
                            CountdownNextUpCard(event: nextEvent)
                        }

                        // Standings (top 3)
                        StandingsWidget(
                            entries: leaderboardViewModel.overallLeaderboard,
                            onSeeAll: { selectedTab = 1 }
                        )

                        // Active Challenges
                        if !challengesViewModel.activeBets.isEmpty {
                            ActiveChallengesWidget(
                                challenges: challengesViewModel.activeBets,
                                standingsResolver: { challengesViewModel.liveStandings(for: $0) }
                            )
                        }

                        // Today's Schedule
                        TodayScheduleWidget(
                            events: viewModel.todayEvents,
                            players: viewModel.currentTrip?.players ?? []
                        )

                        // MARK: - Existing Sections

                        // Travel Status Bar
                        TravelStatusBar(viewModel: viewModel)

                        // Daily Recap
                        NavigationLink {
                            DailyRecapView(viewModel: {
                                if let existing = recapViewModel { return existing }
                                let vm = DailyRecapViewModel(appState: appState)
                                recapViewModel = vm
                                return vm
                            }())
                        } label: {
                            HStack(spacing: 12) {
                                Text("📋")
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.primaryLight)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Daily Recap")
                                        .font(.headline)
                                        .foregroundStyle(Theme.textPrimary)
                                    Text("Awards, scores & highlights")
                                        .font(.caption)
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                            .cardStyle(padded: false)
                        }

                        // Active Polls
                        if !viewModel.activePolls.isEmpty {
                            activePollsSection
                        }

                        // Full Schedule Timeline
                        timelineSection
                    } else {
                        emptyState
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .background(Theme.background)
            .navigationTitle("War Room")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { viewModel.showingAddEvent = true }) {
                            Label("Add Event", systemImage: "calendar.badge.plus")
                        }
                        Button(action: { viewModel.showingCreatePoll = true }) {
                            Label("Create Poll", systemImage: "chart.bar.fill")
                        }
                        Button(action: { viewModel.showingStatusPicker = true }) {
                            Label("Update Status", systemImage: "location.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.primary)
                    }
                    .accessibilityLabel("Add event, poll, or update status")
                }
            }
            .sheet(isPresented: $viewModel.showingAddEvent) {
                AddEventSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingCreatePoll) {
                CreatePollView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingStatusPicker) {
                StatusPickerSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingEventDetail) {
                if let event = viewModel.selectedEvent {
                    EventDetailView(
                        viewModel: viewModel,
                        event: event,
                        players: viewModel.currentTrip?.players ?? [],
                        onDelete: {
                            viewModel.deleteEvent(event)
                            viewModel.showingEventDetail = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Active Polls Section

    @ViewBuilder
    private var activePollsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Polls")
                .sectionHeader()

            ForEach(viewModel.activePolls) { poll in
                PollCardView(
                    poll: poll,
                    players: viewModel.currentTrip?.players ?? [],
                    currentPlayerId: appState.myCurrentPlayer?.id,
                    onVote: { optionId, playerId in
                        viewModel.vote(pollId: poll.id, optionId: optionId, playerId: playerId)
                    },
                    onClose: {
                        viewModel.closePoll(id: poll.id)
                    }
                )
            }
        }
    }

    // MARK: - Timeline Section

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Schedule")
                .sectionHeader()

            let days = viewModel.tripDays()
            if days.isEmpty {
                Text("No trip days configured")
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(days, id: \.self) { day in
                    DaySectionView(
                        dayLabel: viewModel.dayLabel(for: day),
                        events: viewModel.eventsForDay(day),
                        players: viewModel.currentTrip?.players ?? [],
                        onDelete: { event in
                            viewModel.deleteEvent(event)
                        },
                        onTap: { event in
                            viewModel.selectedEvent = event
                            viewModel.showingEventDetail = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 64))
                .foregroundStyle(Theme.primary)
            Text("No Active Trip")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Create or select a trip to access the War Room")
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 80)
    }
}

// MARK: - Next Up Card (Bold Links: solid emerald bg, white text)

struct NextUpCard: View {
    let event: WarRoomEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("NEXT UP")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textOnPrimary.opacity(0.8))
                    .tracking(0.8)
                Spacer()
                Text(event.formattedTime)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textOnPrimary)
            }

            HStack(spacing: 12) {
                Image(systemName: event.type.icon)
                    .font(.title2)
                    .foregroundStyle(Theme.primary)
                    .frame(width: 44, height: 44)
                    .background(Theme.textOnPrimary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(Theme.textOnPrimary)
                    if !event.location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption)
                            Text(event.location)
                                .font(.subheadline)
                        }
                        .foregroundStyle(Theme.textOnPrimary.opacity(0.8))
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.primary)
        )
        .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next up: \(event.title) at \(event.formattedTime)\(!event.location.isEmpty ? ", \(event.location)" : "")")
    }
}

// MARK: - Day Section

struct DaySectionView: View {
    let dayLabel: String
    let events: [WarRoomEvent]
    let players: [Player]
    let onDelete: (WarRoomEvent) -> Void
    let onTap: (WarRoomEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayLabel)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 4)

            if events.isEmpty {
                HStack {
                    Image(systemName: "sun.max")
                        .foregroundStyle(Theme.textSecondary)
                    Text("Free day - no events scheduled")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.background)
                )
            } else {
                ForEach(events) { event in
                    EventCardView(event: event, players: players)
                        .onTapGesture { onTap(event) }
                        .contextMenu {
                            Button(role: .destructive) {
                                onDelete(event)
                            } label: {
                                Label("Delete Event", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Event Card

struct EventCardView: View {
    let event: WarRoomEvent
    let players: [Player]

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(spacing: 2) {
                Text(event.formattedTime)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: 60)

            // Timeline dot
            Circle()
                .fill(eventColor(for: event.type))
                .frame(width: 10, height: 10)

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: event.type.icon)
                        .font(.caption)
                        .foregroundStyle(eventColor(for: event.type))
                    Text(event.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }

                if !event.subtitle.isEmpty {
                    Text(event.subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                if !event.location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(event.location)
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.textSecondary)
                }

                // Player avatars with Bold Links ring style
                if !event.playerIds.isEmpty {
                    HStack(spacing: -6) {
                        let eventPlayers = event.playerIds.compactMap { id in
                            players.first { $0.id == id }
                        }
                        ForEach(Array(eventPlayers.prefix(4))) { player in
                            Text(player.initials)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(player.avatarColor.color)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                        }
                        if eventPlayers.count > 4 {
                            Text("+\(eventPlayers.count - 4)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.textSecondary)
                                .frame(width: 22, height: 22)
                                .background(Theme.background)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                        }
                    }
                }
            }

            Spacer()

            if event.isPast {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.success)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(event.isPast ? Theme.background : Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.border, lineWidth: event.isPast ? 0 : 1)
                )
        )
        .shadow(color: .black.opacity(event.isPast ? 0 : 0.04), radius: 2, y: 1)
        .opacity(event.isPast ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title) at \(event.formattedTime)\(!event.location.isEmpty ? ", \(event.location)" : "")\(event.isPast ? ", completed" : "")")
        .accessibilityHint("Tap for details, long press for options")
    }
}

// MARK: - Status Picker Sheet

struct StatusPickerSheet: View {
    @Bindable var viewModel: WarRoomViewModel
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What's your status?") {
                    ForEach(TravelStatusType.allCases) { statusType in
                        Button {
                            viewModel.selectedStatusType = statusType
                        } label: {
                            HStack {
                                Text(statusType.emoji)
                                    .font(.title2)
                                VStack(alignment: .leading) {
                                    Text(statusType.displayName)
                                        .foregroundStyle(Theme.textPrimary)
                                }
                                Spacer()
                                if viewModel.selectedStatusType == statusType {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.primary)
                                }
                            }
                        }
                    }
                }

                if viewModel.selectedStatusType == .enRoute || viewModel.selectedStatusType == .landed {
                    Section("Flight Info (Optional)") {
                        TextField("e.g. AA 1234", text: $viewModel.statusFlightInfo)
                    }
                }

                Section {
                    if let myPlayer = appState.myCurrentPlayer {
                        Button("Update Status") {
                            viewModel.updateMyStatus(playerId: myPlayer.id)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .font(.headline)
                        .foregroundStyle(Theme.textOnPrimary)
                        .listRowBackground(Theme.primary)
                    }
                }
            }
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.prepareStatusForm()
            }
        }
    }
}

// MARK: - Event Color Helper

func eventColor(for type: EventType) -> Color {
    switch type {
    case .flight: return .blue
    case .hotel: return .purple
    case .teeTime: return Theme.primary
    case .dinner: return .orange
    case .activity: return Theme.warning
    case .transportation: return .teal
    case .custom: return Theme.textSecondary
    }
}

// MARK: - Preview

#Preview("Light") {
    let appState = SampleData.makeAppState()
    WarRoomView(
        viewModel: SampleData.makeWarRoomViewModel(appState: appState),
        leaderboardViewModel: LeaderboardViewModel(appState: appState),
        challengesViewModel: ChallengesViewModel(appState: appState),
        selectedTab: .constant(0)
    )
    .environment(appState)
}

#Preview("Dark") {
    let appState = SampleData.makeAppState()
    WarRoomView(
        viewModel: SampleData.makeWarRoomViewModel(appState: appState),
        leaderboardViewModel: LeaderboardViewModel(appState: appState),
        challengesViewModel: ChallengesViewModel(appState: appState),
        selectedTab: .constant(0)
    )
    .environment(appState)
    .preferredColorScheme(.dark)
}

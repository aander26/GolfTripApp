import SwiftUI

struct EventDetailView: View {
    @Bindable var viewModel: WarRoomViewModel
    let event: WarRoomEvent
    let players: [Player]
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: event.type.icon)
                            .font(.title)
                            .foregroundStyle(eventColor(for: event.type))
                            .frame(width: 56, height: 56)
                            .background(eventColor(for: event.type).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.type.displayName)
                                .font(.caption.bold())
                                .foregroundStyle(eventColor(for: event.type))
                                .textCase(.uppercase)
                                .tracking(0.8)
                            Text(event.title)
                                .font(.title2.bold())
                                .foregroundStyle(Theme.textPrimary)
                            if !event.subtitle.isEmpty {
                                Text(event.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                // Date & Time
                Section("When") {
                    HStack {
                        Label("Date", systemImage: "calendar")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(event.formattedDate)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Label("Time", systemImage: "clock")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text(event.formattedTime)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    if event.endDateTime != nil {
                        HStack {
                            Label("Duration", systemImage: "timer")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(durationText)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }

                // Location
                if !event.location.isEmpty {
                    Section("Location") {
                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .foregroundStyle(Theme.textPrimary)
                    }
                }

                // Players
                let eventPlayers = event.playerIds.compactMap { id in
                    players.first { $0.id == id }
                }
                if !eventPlayers.isEmpty {
                    Section("Attending (\(eventPlayers.count))") {
                        ForEach(eventPlayers) { player in
                            HStack(spacing: 10) {
                                Text(player.initials)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(player.avatarColor.color)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Theme.cardBackground, lineWidth: 2))
                                Text(player.name)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                }

                // Notes
                if !event.notes.isEmpty {
                    Section("Notes") {
                        Text(event.notes)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                // Status
                Section {
                    HStack {
                        if event.isPast {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Theme.success)
                        } else if event.isHappeningNow {
                            Label("Happening Now", systemImage: "livephoto")
                                .foregroundStyle(Theme.warning)
                        } else {
                            Label("Upcoming", systemImage: "clock.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }

                // Delete
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Event", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit") {
                        viewModel.startEditingEvent(event)
                    }
                    .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .sheet(isPresented: $viewModel.showingEditEvent) {
                EditEventSheet(viewModel: viewModel)
            }
        }
    }

    private var durationText: String {
        guard let end = event.endDateTime else { return "" }
        let interval = end.timeIntervalSince(event.dateTime)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Edit Event Sheet

struct EditEventSheet: View {
    @Bindable var viewModel: WarRoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Event Type") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(EventType.allCases) { type in
                                EventTypeButton(
                                    type: type,
                                    isSelected: viewModel.editEventType == type,
                                    onTap: { viewModel.editEventType = type }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Details") {
                    TextField("Title", text: $viewModel.editEventTitle)
                    TextField("Subtitle (optional)", text: $viewModel.editEventSubtitle)
                    TextField("Location (optional)", text: $viewModel.editEventLocation)
                }

                Section("When") {
                    DatePicker("Start", selection: $viewModel.editEventDateTime)

                    Toggle("Has End Time", isOn: $viewModel.editEventHasEndTime)
                        .tint(Theme.primary)

                    if viewModel.editEventHasEndTime {
                        DatePicker("End", selection: $viewModel.editEventEndDateTime)
                    }
                }

                if let trip = viewModel.currentTrip, !trip.players.isEmpty {
                    Section("Who's Involved?") {
                        ForEach(trip.players) { player in
                            Button {
                                if viewModel.editEventPlayerIds.contains(player.id) {
                                    viewModel.editEventPlayerIds.remove(player.id)
                                } else {
                                    viewModel.editEventPlayerIds.insert(player.id)
                                }
                            } label: {
                                HStack {
                                    Text(player.initials)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(player.avatarColor.color)
                                        .clipShape(Circle())
                                    Text(player.name)
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    if viewModel.editEventPlayerIds.contains(player.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Theme.primary)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                            }
                        }

                        Button("Select All") {
                            if let trip = viewModel.currentTrip {
                                viewModel.editEventPlayerIds = Set(trip.players.map(\.id))
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.primary)
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add any details...", text: $viewModel.editEventNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.showingEditEvent = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveEventEdits()
                        dismiss()
                    }
                    .disabled(viewModel.editEventTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    let players = SampleData.playersWithTeams
    let event = WarRoomEvent(
        type: .teeTime,
        title: "Round 1 - Pine Valley",
        subtitle: "Shotgun Start",
        dateTime: Date().addingTimeInterval(3600),
        endDateTime: Date().addingTimeInterval(18000),
        location: "Pine Valley Golf Club",
        notes: "Remember to bring sunscreen! Cart fees are included.",
        playerIds: players.map(\.id)
    )
    EventDetailView(
        viewModel: SampleData.makeWarRoomViewModel(),
        event: event,
        players: players,
        onDelete: {}
    )
}

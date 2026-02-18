import SwiftUI

struct AddEventSheet: View {
    @Bindable var viewModel: WarRoomViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Event Type Picker
                Section("Event Type") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(EventType.allCases) { type in
                                EventTypeButton(
                                    type: type,
                                    isSelected: viewModel.newEventType == type,
                                    onTap: { viewModel.newEventType = type }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Details
                Section("Details") {
                    TextField("Title", text: $viewModel.newEventTitle)
                    TextField("Subtitle (optional)", text: $viewModel.newEventSubtitle)
                    TextField("Location (optional)", text: $viewModel.newEventLocation)
                }

                // Date & Time
                Section("When") {
                    DatePicker("Start", selection: $viewModel.newEventDateTime)

                    Toggle("Has End Time", isOn: $viewModel.newEventHasEndTime)
                        .tint(Theme.primary)

                    if viewModel.newEventHasEndTime {
                        DatePicker("End", selection: $viewModel.newEventEndDateTime)
                    }
                }

                // Players
                if let trip = viewModel.currentTrip, !trip.players.isEmpty {
                    Section("Who's Involved?") {
                        ForEach(trip.players) { player in
                            Button {
                                if viewModel.newEventPlayerIds.contains(player.id) {
                                    viewModel.newEventPlayerIds.remove(player.id)
                                } else {
                                    viewModel.newEventPlayerIds.insert(player.id)
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
                                    if viewModel.newEventPlayerIds.contains(player.id) {
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
                                viewModel.newEventPlayerIds = Set(trip.players.map(\.id))
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Theme.primary)
                    }
                }

                // Notes
                Section("Notes (Optional)") {
                    TextField("Add any details...", text: $viewModel.newEventNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetEventForm()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        viewModel.addEvent()
                        dismiss()
                    }
                    .disabled(viewModel.newEventTitle.isEmpty)
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.newEventTitle.isEmpty ? Theme.textSecondary : Theme.primary)
                }
            }
        }
    }
}

struct EventTypeButton: View {
    let type: EventType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? eventColor(for: type) : Theme.background)
                    .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? eventColor(for: type) : Theme.border, lineWidth: isSelected ? 0 : 1)
                    )

                Text(type.displayName)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 68)
    }
}

#Preview {
    AddEventSheet(viewModel: SampleData.makeWarRoomViewModel())
        .environment(SampleData.makeAppState())
}

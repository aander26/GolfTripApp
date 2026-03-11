import Foundation
import SwiftUI

@MainActor @Observable
class WarRoomViewModel {
    var appState: AppState

    // Sheet state
    var showingAddEvent = false
    var showingCreatePoll = false
    var showingStatusPicker = false
    var showingEventDetail = false
    var selectedEvent: WarRoomEvent?
    var selectedDay: Date?

    // Event form state
    var newEventType: EventType = .teeTime
    var newEventTitle: String = ""
    var newEventSubtitle: String = ""
    var newEventDateTime: Date = Date()
    var newEventEndDateTime: Date = Date()
    var newEventHasEndTime: Bool = false
    var newEventLocation: String = ""
    var newEventNotes: String = ""
    var newEventPlayerIds: Set<UUID> = []

    // Poll form state
    var newPollQuestion: String = ""
    var newPollOptions: [String] = ["", ""]
    var newPollAllowMultiple: Bool = false

    // Status form state
    var selectedStatusType: TravelStatusType = .notDeparted
    var statusFlightInfo: String = ""

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? {
        appState.currentTrip
    }

    // MARK: - Timeline Data

    enum TimelineItem: Identifiable {
        case event(WarRoomEvent)
        case poll(Poll)
        case statusUpdate(TravelStatus, Player)

        var id: String {
            switch self {
            case .event(let e): return "event-\(e.id)"
            case .poll(let p): return "poll-\(p.id)"
            case .statusUpdate(let s, _): return "status-\(s.id)"
            }
        }

        var date: Date {
            switch self {
            case .event(let e): return e.dateTime
            case .poll(let p): return p.createdAt
            case .statusUpdate(let s, _): return s.updatedAt
            }
        }
    }

    var timelineItems: [TimelineItem] {
        guard let trip = currentTrip else { return [] }

        var items: [TimelineItem] = []

        // Add events
        for event in trip.warRoomEvents {
            items.append(.event(event))
        }

        // Add active polls
        for poll in trip.activePolls {
            items.append(.poll(poll))
        }

        // Add recent status updates (last 24 hours)
        let oneDayAgo = Date().addingTimeInterval(-86400)
        for status in trip.travelStatuses {
            if status.updatedAt > oneDayAgo, let player = status.player {
                items.append(.statusUpdate(status, player))
            }
        }

        return items.sorted { $0.date < $1.date }
    }

    var timelineByDay: [(date: Date, items: [TimelineItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timelineItems) { item in
            calendar.startOfDay(for: item.date)
        }
        return grouped
            .map { (date: $0.key, items: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.date < $1.date }
    }

    var upcomingEvents: [WarRoomEvent] {
        guard let trip = currentTrip else { return [] }
        return trip.warRoomEvents
            .filter { $0.isUpcoming }
            .sorted { $0.dateTime < $1.dateTime }
    }

    var nextEvent: WarRoomEvent? {
        upcomingEvents.first
    }

    var playerStatuses: [(Player, TravelStatus?)] {
        guard let trip = currentTrip else { return [] }
        return trip.players.map { player in
            (player, trip.travelStatus(forPlayer: player.id))
        }
    }

    var activePolls: [Poll] {
        currentTrip?.activePolls ?? []
    }

    // MARK: - Event CRUD

    func addEvent() {
        guard !newEventTitle.isEmpty, let trip = currentTrip else { return }
        let event = WarRoomEvent(
            type: newEventType,
            title: newEventTitle,
            subtitle: newEventSubtitle,
            dateTime: newEventDateTime,
            endDateTime: newEventHasEndTime ? newEventEndDateTime : nil,
            location: newEventLocation,
            notes: newEventNotes,
            playerIds: Array(newEventPlayerIds)
        )
        trip.addWarRoomEvent(event)
        appState.saveContext()
        resetEventForm()
    }

    func deleteEvent(_ event: WarRoomEvent) {
        guard let trip = currentTrip else { return }
        trip.removeWarRoomEvent(id: event.id)
        appState.saveContext()
    }

    func updateEvent(_ event: WarRoomEvent) {
        // With reference types, the event is already mutated in-place
        appState.saveContext()
    }

    // MARK: - Travel Status

    func updateMyStatus(playerId: UUID) {
        guard let trip = currentTrip,
              let player = trip.player(withId: playerId) else { return }
        let status = TravelStatus(
            player: player,
            status: selectedStatusType,
            updatedAt: Date(),
            flightInfo: statusFlightInfo
        )
        trip.updateTravelStatus(status)
        appState.saveContext()
        showingStatusPicker = false
        statusFlightInfo = ""
    }

    // MARK: - Polls

    func createPoll() {
        guard !newPollQuestion.isEmpty, let trip = currentTrip else { return }
        let options = newPollOptions
            .filter { !$0.isEmpty }
            .map { PollOption(text: $0) }
        guard options.count >= 2 else { return }

        let poll = Poll(
            question: newPollQuestion,
            options: options,
            allowMultipleVotes: newPollAllowMultiple
        )
        trip.addPoll(poll)
        appState.saveContext()
        resetPollForm()
    }

    func vote(pollId: UUID, optionId: UUID, playerId: UUID) {
        guard let trip = currentTrip,
              let poll = trip.polls.first(where: { $0.id == pollId }) else { return }
        poll.toggleVote(optionId: optionId, playerId: playerId)
        appState.saveContext()
    }

    func closePoll(id: UUID) {
        guard let trip = currentTrip else { return }
        trip.closePoll(id: id)
        appState.saveContext()
    }

    // MARK: - Form Reset

    func resetEventForm() {
        newEventType = .teeTime
        newEventTitle = ""
        newEventSubtitle = ""
        newEventDateTime = Date()
        newEventEndDateTime = Date()
        newEventHasEndTime = false
        newEventLocation = ""
        newEventNotes = ""
        newEventPlayerIds = []
        showingAddEvent = false
    }

    func resetPollForm() {
        newPollQuestion = ""
        newPollOptions = ["", ""]
        newPollAllowMultiple = false
        showingCreatePoll = false
    }

    // MARK: - Helpers

    func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

    func eventsForDay(_ date: Date) -> [WarRoomEvent] {
        guard let trip = currentTrip else { return [] }
        let calendar = Calendar.current
        return trip.warRoomEvents
            .filter { calendar.isDate($0.dateTime, inSameDayAs: date) }
            .sorted { $0.dateTime < $1.dateTime }
    }

    func tripDays() -> [Date] {
        guard let trip = currentTrip else { return [] }
        let calendar = Calendar.current
        var days: [Date] = []
        var current = calendar.startOfDay(for: trip.startDate)
        let end = calendar.startOfDay(for: trip.endDate)
        while current <= end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
        }
        return days
    }
}

import Foundation
import SwiftData

@Model
final class WarRoomEvent {
    var id: UUID = UUID()
    var typeRaw: String = "custom"
    var title: String = ""
    var subtitle: String = ""
    var dateTime: Date = Date()
    var endDateTime: Date?
    var location: String = ""
    var notes: String = ""
    var playerIds: [UUID] = []
    var createdBy: UUID?
    var createdAt: Date = Date()

    // Relationships
    @Relationship(inverse: \Trip.warRoomEvents)
    var trip: Trip?

    init(
        id: UUID = UUID(),
        type: EventType,
        title: String,
        subtitle: String = "",
        dateTime: Date,
        endDateTime: Date? = nil,
        location: String = "",
        notes: String = "",
        playerIds: [UUID] = [],
        createdBy: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.title = title
        self.subtitle = subtitle
        self.dateTime = dateTime
        self.endDateTime = endDateTime
        self.location = location
        self.notes = notes
        self.playerIds = playerIds
        self.createdBy = createdBy
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var type: EventType {
        get { EventType(rawValue: typeRaw) ?? .custom }
        set { typeRaw = newValue.rawValue }
    }

    var isPast: Bool {
        dateTime < Date()
    }

    var isUpcoming: Bool {
        !isPast
    }

    var isHappeningNow: Bool {
        guard let end = endDateTime else { return false }
        let now = Date()
        return dateTime <= now && now <= end
    }

    var formattedTime: String {
        CachedFormatters.time.string(from: dateTime)
    }

    var formattedDate: String {
        CachedFormatters.weekdayShortDate.string(from: dateTime)
    }

    var formattedDateShort: String {
        CachedFormatters.shortDate.string(from: dateTime)
    }
}

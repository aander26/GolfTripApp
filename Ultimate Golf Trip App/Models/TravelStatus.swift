import Foundation
import SwiftData

@Model
final class TravelStatus {
    var id: UUID = UUID()
    var statusRaw: String = "notDeparted"
    var updatedAt: Date = Date()
    var flightInfo: String = ""
    var eta: Date?

    // Relationships
    var player: Player?
    @Relationship(inverse: \Trip.travelStatuses)
    var trip: Trip?

    init(
        id: UUID = UUID(),
        player: Player? = nil,
        status: TravelStatusType = .notDeparted,
        updatedAt: Date = Date(),
        flightInfo: String = "",
        eta: Date? = nil
    ) {
        self.id = id
        self.player = player
        self.statusRaw = status.rawValue
        self.updatedAt = updatedAt
        self.flightInfo = flightInfo
        self.eta = eta
    }

    // MARK: - Computed Properties

    var status: TravelStatusType {
        get { TravelStatusType(rawValue: statusRaw) ?? .notDeparted }
        set { statusRaw = newValue.rawValue }
    }

    /// Backward-compat
    var playerId: UUID? { player?.id }

    var timeSinceUpdate: String {
        let interval = Date().timeIntervalSince(updatedAt)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

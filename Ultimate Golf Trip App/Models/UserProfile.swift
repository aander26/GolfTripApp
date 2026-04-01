import Foundation
import SwiftUI
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var handicapIndex: Double = 0.0
    var avatarColorRaw: String = "blue"
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        handicapIndex: Double = 0.0,
        avatarColor: PlayerColor = .blue,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.handicapIndex = handicapIndex
        self.avatarColorRaw = avatarColor.rawValue
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    var avatarColor: PlayerColor {
        get { PlayerColor(rawValue: avatarColorRaw) ?? .blue }
        set { avatarColorRaw = newValue.rawValue }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    var formattedHandicap: String {
        if handicapIndex == 0 {
            return "SCR"
        }
        if handicapIndex > 0 {
            return String(format: "%.1f", handicapIndex)
        }
        return "+\(String(format: "%.1f", abs(handicapIndex)))"
    }
}

import Foundation
import SwiftUI
import SwiftData

@Model
final class Player {
    var id: UUID = UUID()
    var name: String = ""
    var handicapIndex: Double = 0.0
    var avatarColorRaw: String = "blue"

    /// Links this Player to the device user's profile (nil for players added by others)
    var userProfileId: UUID?

    // Relationships
    var team: Team?
    @Relationship(inverse: \Trip.players)
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        handicapIndex: Double = 0.0,
        team: Team? = nil,
        avatarColor: PlayerColor = .blue,
        userProfileId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.handicapIndex = handicapIndex
        self.team = team
        self.avatarColorRaw = avatarColor.rawValue
        self.userProfileId = userProfileId
    }

    // MARK: - Computed Properties

    var avatarColor: PlayerColor {
        get { PlayerColor(rawValue: avatarColorRaw) ?? .blue }
        set { avatarColorRaw = newValue.rawValue }
    }

    var isLinkedToUser: Bool {
        userProfileId != nil
    }

    /// Backward-compat: returns team.id if team is set
    var teamId: UUID? {
        team?.id
    }

    var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
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

enum PlayerColor: String, Codable, CaseIterable, Identifiable {
    case blue, green, red, orange, purple, teal, pink, indigo

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .red: return .red
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}

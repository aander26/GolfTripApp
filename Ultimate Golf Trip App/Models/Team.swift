import Foundation
import SwiftUI
import SwiftData

@Model
final class Team {
    var id: UUID
    var name: String
    var colorRaw: String

    // Relationships
    @Relationship(inverse: \Player.team)
    var players: [Player]
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        color: TeamColor = .blue,
        players: [Player] = []
    ) {
        self.id = id
        self.name = name
        self.colorRaw = color.rawValue
        self.players = players
    }

    // MARK: - Computed Properties

    var color: TeamColor {
        get { TeamColor(rawValue: colorRaw) ?? .blue }
        set { colorRaw = newValue.rawValue }
    }

    /// Backward-compat: returns array of player UUIDs
    var playerIds: [UUID] {
        players.map { $0.id }
    }

    var playerCount: Int { players.count }
}

enum TeamColor: String, Codable, CaseIterable, Identifiable {
    case blue = "Blue"
    case red = "Red"
    case green = "Green"
    case gold = "Gold"
    case purple = "Purple"
    case orange = "Orange"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .gold: return .yellow
        case .purple: return .purple
        case .orange: return .orange
        }
    }
}

import Foundation

enum EventType: String, Codable, CaseIterable, Identifiable {
    case flight = "flight"
    case hotel = "hotel"
    case teeTime = "teeTime"
    case dinner = "dinner"
    case activity = "activity"
    case transportation = "transportation"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flight: return "Flight"
        case .hotel: return "Hotel Check-In"
        case .teeTime: return "Tee Time"
        case .dinner: return "Dinner"
        case .activity: return "Activity"
        case .transportation: return "Transportation"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .flight: return "airplane"
        case .hotel: return "building.2.fill"
        case .teeTime: return "figure.golf"
        case .dinner: return "fork.knife"
        case .activity: return "star.fill"
        case .transportation: return "car.fill"
        case .custom: return "calendar.badge.plus"
        }
    }

    var color: String {
        switch self {
        case .flight: return "blue"
        case .hotel: return "purple"
        case .teeTime: return "green"
        case .dinner: return "orange"
        case .activity: return "yellow"
        case .transportation: return "teal"
        case .custom: return "gray"
        }
    }
}

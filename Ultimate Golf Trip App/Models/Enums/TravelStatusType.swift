import Foundation

enum TravelStatusType: String, Codable, CaseIterable, Identifiable {
    case notDeparted = "notDeparted"
    case enRoute = "enRoute"
    case landed = "landed"
    case atHotel = "atHotel"
    case atCourse = "atCourse"
    case atDinner = "atDinner"
    case exploring = "exploring"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .notDeparted: return "Not Departed"
        case .enRoute: return "En Route"
        case .landed: return "Landed"
        case .atHotel: return "At Hotel"
        case .atCourse: return "At Course"
        case .atDinner: return "At Dinner"
        case .exploring: return "Exploring"
        }
    }

    var emoji: String {
        switch self {
        case .notDeparted: return "🏠"
        case .enRoute: return "✈️"
        case .landed: return "🛬"
        case .atHotel: return "🏨"
        case .atCourse: return "⛳"
        case .atDinner: return "🍽️"
        case .exploring: return "🗺️"
        }
    }

    var activityMessage: String {
        switch self {
        case .notDeparted: return "hasn't left yet"
        case .enRoute: return "is on the way"
        case .landed: return "just landed"
        case .atHotel: return "checked into the hotel"
        case .atCourse: return "is at the course"
        case .atDinner: return "is at dinner"
        case .exploring: return "is out exploring"
        }
    }
}

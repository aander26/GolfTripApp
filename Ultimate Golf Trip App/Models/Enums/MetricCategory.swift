import Foundation

enum MetricCategory: String, Codable, CaseIterable, Identifiable {
    case onCourse = "onCourse"
    case offCourse = "offCourse"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onCourse: return "On-Course"
        case .offCourse: return "Off-Course"
        }
    }

    var icon: String {
        switch self {
        case .onCourse: return "figure.golf"
        case .offCourse: return "party.popper.fill"
        }
    }

    var description: String {
        switch self {
        case .onCourse: return "Golf stats beyond the scorecard"
        case .offCourse: return "The stuff that happens between rounds"
        }
    }
}

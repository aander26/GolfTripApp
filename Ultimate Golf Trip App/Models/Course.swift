import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID
    var name: String
    var holes: [Hole]
    var slopeRating: Double
    var courseRating: Double
    var city: String
    var state: String
    var latitude: Double?
    var longitude: Double?

    /// Per-course team scoring rule — defines format and points for team competition on this course.
    /// Optional: nil means no team scoring assigned yet.
    var teamScoringRule: TeamScoringRule?

    // Relationships
    var trip: Trip?

    init(
        id: UUID = UUID(),
        name: String,
        holes: [Hole] = [],
        slopeRating: Double = 113,
        courseRating: Double = 72.0,
        city: String = "",
        state: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        teamScoringRule: TeamScoringRule? = nil
    ) {
        self.id = id
        self.name = name
        self.holes = holes
        self.slopeRating = slopeRating
        self.courseRating = courseRating
        self.city = city
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
        self.teamScoringRule = teamScoringRule
    }

    // MARK: - Computed Properties

    var totalPar: Int {
        holes.reduce(0) { $0 + $1.par }
    }

    var frontNinePar: Int {
        holes.prefix(9).reduce(0) { $0 + $1.par }
    }

    var backNinePar: Int {
        holes.suffix(9).reduce(0) { $0 + $1.par }
    }

    var totalYardage: Int {
        holes.reduce(0) { $0 + $1.yardage }
    }

    var parThreeHoles: [Hole] {
        holes.filter { $0.par == 3 }
    }

    var location: String {
        if city.isEmpty && state.isEmpty { return "" }
        if city.isEmpty { return state }
        if state.isEmpty { return city }
        return "\(city), \(state)"
    }

    static func defaultEighteenHoles() -> [Hole] {
        (1...18).map { number in
            Hole(
                number: number,
                par: number % 3 == 0 ? 3 : (number % 5 == 0 ? 5 : 4),
                yardage: 400,
                handicapRating: number
            )
        }
    }
}

// Stays as Codable struct — small value type stored inline by SwiftData
struct Hole: Identifiable, Codable, Hashable {
    var id: UUID
    var number: Int
    var par: Int
    var yardage: Int
    var handicapRating: Int

    init(
        id: UUID = UUID(),
        number: Int,
        par: Int = 4,
        yardage: Int = 400,
        handicapRating: Int = 1
    ) {
        self.id = id
        self.number = number
        self.par = par
        self.yardage = yardage
        self.handicapRating = handicapRating
    }

    var isParThree: Bool { par == 3 }
    var isParFive: Bool { par == 5 }
}

import Foundation
import SwiftData

@Model
final class Course {
    var id: UUID = UUID()
    var name: String = ""
    var holes: [Hole] = []
    var slopeRating: Double = 113
    var courseRating: Double = 72.0
    var city: String = ""
    var state: String = ""
    var latitude: Double?
    var longitude: Double?

    /// Available tee boxes for this course (populated from database or manual entry)
    var teeBoxes: [TeeBox] = []

    /// The name of the currently selected tee box (e.g. "Blue")
    var selectedTeeBoxName: String?

    /// Per-course team scoring rule — defines format and points for team competition on this course.
    /// Optional: nil means no team scoring assigned yet.
    var teamScoringRule: TeamScoringRule?

    // Relationships
    @Relationship(inverse: \Trip.courses)
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
        teeBoxes: [TeeBox] = [],
        selectedTeeBoxName: String? = nil,
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
        self.teeBoxes = teeBoxes
        self.selectedTeeBoxName = selectedTeeBoxName
        self.teamScoringRule = teamScoringRule
    }

    /// The currently selected tee box, if any
    var selectedTeeBox: TeeBox? {
        guard let name = selectedTeeBoxName else { return nil }
        return teeBoxes.first { $0.name == name }
    }

    /// Apply a tee box selection — updates slope, course rating, and hole yardages
    func applyTeeBox(_ teeBox: TeeBox) {
        selectedTeeBoxName = teeBox.name
        slopeRating = teeBox.slopeRating
        courseRating = teeBox.courseRating
        // Update hole yardages from the tee box data
        for teeHole in teeBox.holes {
            if let idx = holes.firstIndex(where: { $0.number == teeHole.number }) {
                holes[idx].yardage = teeHole.yardage
            }
        }
    }

    // MARK: - Computed Properties

    var totalPar: Int {
        holes.reduce(0) { $0 + $1.par }
    }

    var frontNinePar: Int {
        holes.prefix(9).reduce(0) { $0 + $1.par }
    }

    var backNinePar: Int {
        // Use dropFirst(9) to avoid overlapping with frontNinePar on 9-hole courses
        holes.dropFirst(9).reduce(0) { $0 + $1.par }
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

    /// Generate default 18 holes for a standard par 72 course.
    /// Layout: 4 par 3s, 10 par 4s, 4 par 5s with realistic yardages and handicap ratings.
    static func defaultEighteenHoles() -> [Hole] {
        // Standard par 72 layout: par 3s on holes 3, 7, 12, 17
        // Par 5s on holes 2, 9, 13, 18 — rest are par 4s
        let pars =     [4, 5, 3, 4, 4, 4, 3, 4, 5,  4, 4, 3, 5, 4, 4, 4, 3, 5]
        let yardages = [410, 530, 175, 380, 420, 400, 195, 440, 545,
                        390, 415, 165, 520, 370, 435, 405, 185, 555]
        let handicaps = [7, 11, 15, 3, 1, 9, 13, 5, 17,
                         8, 2, 16, 10, 6, 4, 12, 18, 14]

        return (0..<18).map { i in
            Hole(
                number: i + 1,
                par: pars[i],
                yardage: yardages[i],
                handicapRating: handicaps[i]
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

// MARK: - Tee Box

/// Represents a tee box option for a course (e.g. Blue, White, Red)
/// with its own slope/course ratings and per-hole yardages.
struct TeeBox: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String         // e.g. "Blue", "White", "Red", "Gold", "Black"
    var color: String        // Used for display (e.g. "blue", "white", "red")
    var slopeRating: Double
    var courseRating: Double
    var totalYardage: Int
    var holes: [TeeBoxHole]  // Per-hole yardage for this tee box

    init(
        id: UUID = UUID(),
        name: String,
        color: String = "",
        slopeRating: Double = 113,
        courseRating: Double = 72.0,
        totalYardage: Int = 0,
        holes: [TeeBoxHole] = []
    ) {
        self.id = id
        self.name = name
        self.color = color.isEmpty ? name.lowercased() : color
        self.slopeRating = slopeRating
        self.courseRating = courseRating
        self.totalYardage = totalYardage > 0 ? totalYardage : holes.reduce(0) { $0 + $1.yardage }
        self.holes = holes
    }
}

/// Per-hole yardage for a specific tee box
struct TeeBoxHole: Codable, Hashable {
    var number: Int
    var yardage: Int
}

import Foundation

// MARK: - Data Types

/// Codable representation of a golf course with full hole data.
struct CourseData: Codable, Identifiable {
    var id: String { name + city + state }
    let name: String
    let city: String
    let state: String
    let slopeRating: Double
    let courseRating: Double
    let holes: [HoleData]

    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
    var totalYardage: Int { holes.reduce(0) { $0 + $1.yardage } }
}

/// Codable representation of a single hole.
struct HoleData: Codable {
    let number: Int
    let par: Int
    let yardage: Int
    let handicapRating: Int
}

// MARK: - Golf Course Database

/// Loads and searches a bundled JSON database of popular golf courses.
class GolfCourseDatabase {
    static let shared = GolfCourseDatabase()

    private lazy var courses: [CourseData] = loadCourses()

    private init() {}

    // MARK: - Search

    /// Find a course by name, with optional city/state for disambiguation.
    /// Uses fuzzy matching on the name.
    func findCourse(name: String, city: String = "", state: String = "") -> CourseData? {
        let normalizedName = normalize(name)

        // 1. Exact name match (case-insensitive)
        if let exact = courses.first(where: { normalize($0.name) == normalizedName }) {
            return exact
        }

        // 2. Name contains match (handles "Pinehurst Resort - No. 2" matching "Pinehurst No. 2")
        let nameMatches = courses.filter { course in
            let courseName = normalize(course.name)
            return courseName.contains(normalizedName) || normalizedName.contains(courseName)
        }

        if nameMatches.count == 1 {
            return nameMatches.first
        }

        // 3. If multiple name matches, disambiguate by location
        if nameMatches.count > 1 && (!city.isEmpty || !state.isEmpty) {
            let locationMatch = nameMatches.first { course in
                let cityMatch = city.isEmpty || normalize(course.city).contains(normalize(city))
                let stateMatch = state.isEmpty || normalize(course.state) == normalize(state)
                return cityMatch || stateMatch
            }
            if let match = locationMatch { return match }
        }

        // 4. Word-based fuzzy match: check if key words from the search appear in course name
        let searchWords = normalizedName.split(separator: " ").map(String.init).filter { $0.count > 2 }
        let fuzzyMatches = courses.filter { course in
            let courseName = normalize(course.name)
            let matchingWords = searchWords.filter { courseName.contains($0) }
            return matchingWords.count >= max(1, searchWords.count - 1)
        }

        if fuzzyMatches.count == 1 {
            return fuzzyMatches.first
        }

        // 5. Disambiguate fuzzy matches by location
        if fuzzyMatches.count > 1 && (!city.isEmpty || !state.isEmpty) {
            return fuzzyMatches.first { course in
                let cityMatch = city.isEmpty || normalize(course.city).contains(normalize(city))
                let stateMatch = state.isEmpty || normalize(course.state) == normalize(state)
                return cityMatch || stateMatch
            }
        }

        return fuzzyMatches.first
    }

    /// Get all courses in the database.
    var allCourses: [CourseData] { courses }

    /// Get the count of bundled courses.
    var courseCount: Int { courses.count }

    // MARK: - Private

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "golf course", with: "")
            .replacingOccurrences(of: "golf club", with: "")
            .replacingOccurrences(of: "golf links", with: "")
            .replacingOccurrences(of: "golf & country club", with: "")
            .replacingOccurrences(of: "country club", with: "")
            .replacingOccurrences(of: "resort", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func loadCourses() -> [CourseData] {
        guard let url = Bundle.main.url(forResource: "popular_courses", withExtension: "json") else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([CourseData].self, from: data)
            return decoded
        } catch {
            return []
        }
    }
}

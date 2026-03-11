import Foundation
import os

// MARK: - Data Types

/// Codable representation of a golf course with full hole data.
/// Used both as the in-memory model and for API results.
struct CourseData: Identifiable, Sendable {
    var id: String { name + city + state }
    let name: String
    let city: String
    let state: String
    let slopeRating: Double
    let courseRating: Double
    let holes: [HoleData]
    let teeBoxes: [TeeBoxData]?

    var totalPar: Int { holes.reduce(0) { $0 + $1.par } }
    var totalYardage: Int { holes.reduce(0) { $0 + $1.yardage } }
}

/// Codable representation of a single hole.
struct HoleData: Codable, Sendable {
    let number: Int
    let par: Int
    let yardage: Int
    let handicapRating: Int
}

/// Codable representation of a tee box option.
struct TeeBoxData: Sendable {
    let name: String
    let color: String?
    let slopeRating: Double
    let courseRating: Double
    let holes: [TeeBoxHoleData]?
    let totalYardage: Int

    init(name: String, color: String? = nil, slopeRating: Double, courseRating: Double, holes: [TeeBoxHoleData]? = nil, totalYardage: Int? = nil) {
        self.name = name
        self.color = color
        self.slopeRating = slopeRating
        self.courseRating = courseRating
        self.holes = holes
        self.totalYardage = totalYardage ?? holes?.reduce(0) { $0 + $1.yardage } ?? 0
    }
}

/// Per-hole yardage for a specific tee box in the JSON database.
struct TeeBoxHoleData: Codable, Sendable {
    let number: Int
    let yardage: Int
}

// MARK: - Compact JSON Decoding

/// The bundled JSON uses a compact format with short keys and array-based holes
/// to minimize file size (~2.5 MB for ~5K courses).
///
/// Format:
/// ```json
/// {"n":"Course Name","ci":"City","st":"State","sl":135,"cr":75.3,
///  "h":[[par,yardage,handicap],...],
///  "t":[{"n":"Tee Name","s":119,"r":67.3,"y":4680},...]}
/// ```
private struct CompactCourse: Codable {
    let n: String           // name
    let ci: String          // city
    let st: String          // state
    let sl: Double          // slopeRating
    let cr: Double          // courseRating
    let h: [[Int]]          // holes as [par, yardage, handicapRating]
    let t: [CompactTeeBox]? // teeBoxes

    func toCourseData() -> CourseData {
        let holes = h.enumerated().map { index, arr in
            HoleData(
                number: index + 1,
                par: arr.count > 0 ? arr[0] : 4,
                yardage: arr.count > 1 ? arr[1] : 400,
                handicapRating: arr.count > 2 ? arr[2] : index + 1
            )
        }

        let teeBoxes = t?.map { tee in
            TeeBoxData(
                name: tee.n,
                slopeRating: tee.s,
                courseRating: tee.r,
                totalYardage: tee.y
            )
        }

        return CourseData(
            name: n,
            city: ci,
            state: st,
            slopeRating: sl,
            courseRating: cr,
            holes: holes,
            teeBoxes: teeBoxes
        )
    }
}

private struct CompactTeeBox: Codable {
    let n: String  // name
    let s: Double  // slopeRating
    let r: Double  // courseRating
    let y: Int     // totalYardage
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

    /// Convert CourseData tee boxes to the app's TeeBox model.
    /// If the JSON has explicit tee box data, those are used directly.
    /// For compact tee data (no per-hole yardages), hole yardages are derived
    /// by distributing the total yardage proportionally across the course holes.
    /// Otherwise, standard tee options are derived from the championship tee data.
    func teeBoxes(for courseData: CourseData) -> [TeeBox] {
        // If the JSON has explicit tee box data, use it
        if let teeData = courseData.teeBoxes, !teeData.isEmpty {
            return teeData.map { data in
                // If per-hole data exists, use it directly
                if let holeData = data.holes, !holeData.isEmpty {
                    return TeeBox(
                        name: data.name,
                        color: data.color ?? data.name.lowercased(),
                        slopeRating: data.slopeRating,
                        courseRating: data.courseRating,
                        holes: holeData.map { TeeBoxHole(number: $0.number, yardage: $0.yardage) }
                    )
                }

                // Compact format: derive per-hole yardages from totalYardage
                // by scaling the championship hole yardages proportionally
                let champYardage = courseData.totalYardage
                let teeYardage = data.totalYardage
                let holes: [TeeBoxHole]
                if champYardage > 0 && teeYardage > 0 {
                    let ratio = Double(teeYardage) / Double(champYardage)
                    holes = courseData.holes.map { hole in
                        TeeBoxHole(number: hole.number, yardage: Int(Double(hole.yardage) * ratio))
                    }
                } else {
                    holes = []
                }

                return TeeBox(
                    name: data.name,
                    color: data.color ?? data.name.lowercased(),
                    slopeRating: data.slopeRating,
                    courseRating: data.courseRating,
                    totalYardage: teeYardage,
                    holes: holes
                )
            }
        }

        // No tee data — generate standard tee options from the championship tee data
        let champSlope = courseData.slopeRating
        let champRating = courseData.courseRating
        let champYardage = courseData.totalYardage

        var boxes: [TeeBox] = []

        // Championship / Back Tees (the data in the JSON)
        boxes.append(TeeBox(
            name: "Back",
            color: "black",
            slopeRating: champSlope,
            courseRating: champRating,
            totalYardage: champYardage,
            holes: courseData.holes.map { TeeBoxHole(number: $0.number, yardage: $0.yardage) }
        ))

        // Middle Tees (~92% of championship yardage)
        let middleFactor = 0.92
        boxes.append(TeeBox(
            name: "Middle",
            color: "blue",
            slopeRating: max(100, champSlope - 4),
            courseRating: max(65, champRating - 1.8),
            totalYardage: Int(Double(champYardage) * middleFactor),
            holes: courseData.holes.map { TeeBoxHole(number: $0.number, yardage: Int(Double($0.yardage) * middleFactor)) }
        ))

        // Forward Tees (~83% of championship yardage)
        let forwardFactor = 0.83
        boxes.append(TeeBox(
            name: "Forward",
            color: "white",
            slopeRating: max(90, champSlope - 10),
            courseRating: max(62, champRating - 4.2),
            totalYardage: Int(Double(champYardage) * forwardFactor),
            holes: courseData.holes.map { TeeBoxHole(number: $0.number, yardage: Int(Double($0.yardage) * forwardFactor)) }
        ))

        // Front Tees (~74% of championship yardage)
        let frontFactor = 0.74
        boxes.append(TeeBox(
            name: "Front",
            color: "red",
            slopeRating: max(80, champSlope - 16),
            courseRating: max(58, champRating - 7.0),
            totalYardage: Int(Double(champYardage) * frontFactor),
            holes: courseData.holes.map { TeeBoxHole(number: $0.number, yardage: Int(Double($0.yardage) * frontFactor)) }
        ))

        return boxes
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

    private static let dbLogger = Logger(subsystem: "com.alex-apps.golftrip", category: "GolfCourseDatabase")

    private func loadCourses() -> [CourseData] {
        guard let url = Bundle.main.url(forResource: "popular_courses", withExtension: "json") else {
            Self.dbLogger.error("popular_courses.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            let compactCourses = try JSONDecoder().decode([CompactCourse].self, from: data)
            let courses = compactCourses.map { $0.toCourseData() }
            Self.dbLogger.info("Loaded \(courses.count) courses from bundled database")
            return courses
        } catch {
            Self.dbLogger.error("Failed to decode courses: \(error)")
            return []
        }
    }
}

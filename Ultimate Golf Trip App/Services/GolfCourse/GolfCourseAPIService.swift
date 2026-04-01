import Foundation

// MARK: - Golf Course API Service
// Fetches live course data (tee boxes, slope, rating, hole details) from GolfCourseAPI.com.
// Free tier: 300 requests/day.
//
// The API only supports paginated browsing and single-course lookup by ID.
// It does NOT support name-based search, so we use the bundled database (~5K+ courses)
// as the primary source and fall back to the API's paginated listing.
// We use alphabetical estimation to jump to approximately the right page.

actor GolfCourseAPIService {
    static let shared = GolfCourseAPIService()

    private let baseURL = "https://api.golfcourseapi.com/v1"
    private let session: URLSession
    private let decoder: JSONDecoder

    /// In-memory cache of API lookups
    private var cache: [String: CourseData] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    /// API key stored in Info.plist under key "GolfCourseAPIKey"
    private var apiKey: String? {
        Bundle.main.object(forInfoDictionaryKey: "GolfCourseAPIKey") as? String
    }

    /// Whether the API is configured (has an API key)
    var isConfigured: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }

    // MARK: - Course Lookup

    /// Daily request budget tracking (free tier: 300/day)
    private var requestCount: Int = 0
    private var requestCountDate: Date?
    private let maxDailyRequests = 250 // Leave buffer

    /// Check-only: returns true if budget remains, without incrementing.
    private var canMakeRequest: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        if requestCountDate != today {
            requestCount = 0
            requestCountDate = today
        }
        return requestCount < maxDailyRequests
    }

    /// Atomically checks and increments the request counter.
    /// Returns true if the request is allowed, false if the daily budget is exhausted.
    private func consumeRequest() -> Bool {
        guard canMakeRequest else { return false }
        requestCount += 1
        return true
    }

    /// Search for a course by name and location.
    /// Uses alphabetical page estimation to find the right section of the API's
    /// paginated listing (~25K courses in alphabetical order, ~20 per page).
    func findCourse(name: String, city: String = "", state: String = "") async -> CourseData? {
        guard isConfigured else { return nil }
        guard let key = apiKey, !key.isEmpty else { return nil }

        let cacheKey = "\(name.lowercased())|\(city.lowercased())|\(state.lowercased())"
        if let cached = cache[cacheKey] {
            return cached
        }

        let normalizedName = name.lowercased()

        // Estimate which page to start on based on the first letter
        // API has ~25K courses, ~20 per page = ~1,250 pages, alphabetically sorted
        let estimatedPage = estimatePageForName(normalizedName)

        // Search nearby pages (check estimated page ± 2)
        let pagesToTry = [estimatedPage, estimatedPage - 1, estimatedPage + 1, estimatedPage - 2, estimatedPage + 2]
            .filter { $0 >= 1 }

        for page in pagesToTry {
            guard consumeRequest() else { break }

            guard let result = await fetchPageAndSearch(page: page, name: normalizedName, key: key) else {
                continue
            }

            cache[cacheKey] = result
            return result
        }

        return nil
    }

    /// Estimate which API page a course name would appear on (alphabetical order).
    /// Based on ~25K courses, 20 per page, roughly uniform distribution.
    private func estimatePageForName(_ name: String) -> Int {
        // Approximate page ranges by first letter based on typical golf course name distribution
        // Many courses start with common words, so distribution isn't perfectly uniform
        let letterPages: [Character: Int] = [
            "a": 1, "b": 80, "c": 180, "d": 300, "e": 370,
            "f": 410, "g": 460, "h": 520, "i": 580, "j": 600,
            "k": 620, "l": 650, "m": 710, "n": 790, "o": 830,
            "p": 860, "q": 920, "r": 930, "s": 990, "t": 1100,
            "u": 1160, "v": 1170, "w": 1190, "x": 1230, "y": 1235,
            "z": 1240
        ]

        guard let firstChar = name.first else { return 1 }
        return letterPages[firstChar] ?? 1
    }

    /// Fetch a single page and search for a matching course name.
    private func fetchPageAndSearch(page: Int, name: String, key: String) async -> CourseData? {
        guard let url = URL(string: "\(baseURL)/courses?page=\(page)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            guard consumeRequest() else { return nil }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let apiResponse = try Self.decodeListResponse(data, decoder: decoder)

            // Check each course for a STRONG name match using word-level comparison.
            // Simple substring matching is too loose and can match completely wrong courses.
            for course in apiResponse.courses {
                let courseName = course.courseName.lowercased()
                if isStrongNameMatch(searchName: name, candidateName: courseName) {
                    return course.toCourseData()
                }
            }
        } catch {
            // API error
        }

        return nil
    }

    /// Check if two course names are a strong match using word-level comparison.
    /// Requires significant word overlap to prevent matching wrong courses.
    /// e.g. "arthur hills at palmetto dunes" should NOT match "palmetto dunes resort" (different course).
    private func isStrongNameMatch(searchName: String, candidateName: String) -> Bool {
        // Filler words that don't help identify a specific course
        let fillerWords: Set<String> = [
            "the", "at", "of", "and", "a", "an", "golf", "course", "club",
            "country", "resort", "links", "oceanfront", "plantation", "tpc"
        ]

        let searchWords = Set(searchName.split(separator: " ").map { String($0) })
            .subtracting(fillerWords)
        let candidateWords = Set(candidateName.split(separator: " ").map { String($0) })
            .subtracting(fillerWords)

        guard !searchWords.isEmpty, !candidateWords.isEmpty else {
            // Fallback: exact match only if all words were filler
            return searchName == candidateName
        }

        let overlap = searchWords.intersection(candidateWords)
        let smallerSet = min(searchWords.count, candidateWords.count)

        // Require at least 60% of the smaller name's significant words to match
        let threshold = max(1, Int(ceil(Double(smallerSet) * 0.6)))
        return overlap.count >= threshold
    }

    /// Fetch a specific course by its GolfCourseAPI ID.
    func fetchCourseById(_ id: Int) async -> CourseData? {
        guard let key = apiKey, !key.isEmpty else { return nil }

        let cacheKey = "id:\(id)"
        if let cached = cache[cacheKey] {
            return cached
        }

        guard let url = URL(string: "\(baseURL)/courses/\(id)") else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Key \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

            let apiResponse = try Self.decodeSingleResponse(data, decoder: decoder)
            if let courseData = apiResponse.course.toCourseData() {
                cache[cacheKey] = courseData
                return courseData
            }
        } catch {
            // API error — return nil
        }

        return nil
    }
    // MARK: - Nonisolated Decoders

    private nonisolated static func decodeListResponse(_ data: Data, decoder: JSONDecoder) throws -> GolfCourseAPIListResponse {
        try decoder.decode(GolfCourseAPIListResponse.self, from: data)
    }

    private nonisolated static func decodeSingleResponse(_ data: Data, decoder: JSONDecoder) throws -> GolfCourseAPISingleResponse {
        try decoder.decode(GolfCourseAPISingleResponse.self, from: data)
    }
}

// MARK: - API Response Models

private struct GolfCourseAPIListResponse: Codable, Sendable {
    let courses: [GolfCourseAPICourse]
}

private struct GolfCourseAPISingleResponse: Codable, Sendable {
    let course: GolfCourseAPICourse
}

private struct GolfCourseAPICourse: Codable, Sendable {
    let id: Int
    let clubName: String?
    let courseName: String
    let location: GolfCourseAPILocation
    let tees: GolfCourseAPITees

    /// Convert API result to our internal CourseData model
    func toCourseData() -> CourseData? {
        // Collect all tees (male + female)
        let allTees = (tees.male ?? []) + (tees.female ?? [])

        // Get par/handicap from the first tee that has hole data
        guard let firstTeeWithHoles = allTees.first(where: { !($0.holes ?? []).isEmpty }),
              let holesList = firstTeeWithHoles.holes, !holesList.isEmpty else {
            return nil // No hole data available
        }

        // Build hole data array
        let holeData: [HoleData] = holesList.enumerated().map { index, hole in
            HoleData(
                number: index + 1,
                par: hole.par ?? 4,
                yardage: hole.yardage ?? 400,
                handicapRating: hole.handicap ?? (index + 1)
            )
        }

        // Build tee box data — group male tees first, then female
        var teeBoxData: [TeeBoxData] = []

        for tee in (tees.male ?? []) {
            let teeHoles = tee.holes ?? []
            let holeData = teeHoles.enumerated().map { i, h in
                TeeBoxHoleData(number: i + 1, yardage: h.yardage ?? 0)
            }
            teeBoxData.append(TeeBoxData(
                name: tee.teeName ?? "Unknown",
                color: (tee.teeName ?? "").lowercased(),
                slopeRating: tee.slopeRating ?? 113,
                courseRating: tee.courseRating ?? 72.0,
                holes: holeData,
                totalYardage: tee.totalYards
            ))
        }

        for tee in (tees.female ?? []) {
            let teeHoles = tee.holes ?? []
            let holeData = teeHoles.enumerated().map { i, h in
                TeeBoxHoleData(number: i + 1, yardage: h.yardage ?? 0)
            }
            teeBoxData.append(TeeBoxData(
                name: "\(tee.teeName ?? "Unknown") (W)",
                color: (tee.teeName ?? "").lowercased(),
                slopeRating: tee.slopeRating ?? 113,
                courseRating: tee.courseRating ?? 72.0,
                holes: holeData,
                totalYardage: tee.totalYards
            ))
        }

        // Default slope/rating from first male tee
        let defaultSlope = tees.male?.first?.slopeRating ?? 113
        let defaultRating = tees.male?.first?.courseRating ?? 72.0

        return CourseData(
            name: courseName,
            city: location.city ?? "",
            state: location.state ?? "",
            slopeRating: defaultSlope,
            courseRating: defaultRating,
            holes: holeData,
            teeBoxes: teeBoxData.isEmpty ? nil : teeBoxData
        )
    }
}

private struct GolfCourseAPILocation: Codable, Sendable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

private struct GolfCourseAPITees: Codable, Sendable {
    let male: [GolfCourseAPITee]?
    let female: [GolfCourseAPITee]?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // The API returns empty object {} when no tees, so handle both cases
        self.male = try? container.decodeIfPresent([GolfCourseAPITee].self, forKey: .male)
        self.female = try? container.decodeIfPresent([GolfCourseAPITee].self, forKey: .female)
    }

    private enum CodingKeys: String, CodingKey {
        case male, female
    }
}

private struct GolfCourseAPITee: Codable, Sendable {
    let teeName: String?
    let courseRating: Double?
    let slopeRating: Double?
    let bogeyRating: Double?
    let totalYards: Int?
    let totalMeters: Int?
    let numberOfHoles: Int?
    let parTotal: Int?
    let holes: [GolfCourseAPIHole]?
}

private struct GolfCourseAPIHole: Codable, Sendable {
    let par: Int?
    let yardage: Int?
    let handicap: Int?
}

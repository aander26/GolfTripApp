import Foundation
import MapKit

// MARK: - Course Search Result

/// A resolved course suggestion with location details and optional scorecard data.
struct CourseSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let city: String
    let state: String
    let latitude: Double
    let longitude: Double
    /// Full course data from bundled database (nil if not found)
    let courseData: CourseData?

    var hasDetailedData: Bool { courseData != nil }
}

// MARK: - Golf Course Search Service

/// Provides real-time typeahead search for golf courses using MapKit,
/// with automatic enrichment from the bundled course database.
@Observable
@MainActor
class GolfCourseSearchService: NSObject {

    /// Error message from the last failed search, surfaced in the UI.
    var searchError: String?

    var searchText: String = "" {
        didSet {
            if searchText.count >= 2 {
                completer.queryFragment = searchText
                updateDatabaseMatches(query: searchText)
            } else {
                suggestions = []
                databaseMatches = []
            }
            // Reset selection when search text changes manually
            if !isAutoFilled {
                selectedResult = nil
            }
            isAutoFilled = false
        }
    }

    var suggestions: [MKLocalSearchCompletion] = []
    /// Courses found directly in the bundled database (shown alongside MapKit results)
    var databaseMatches: [CourseData] = []
    var selectedResult: CourseSearchResult?
    var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()
    private let database = GolfCourseDatabase.shared
    private var isAutoFilled = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .pointOfInterest
        // No dedicated golf POI category — we filter results in the delegate callback
    }

    /// Search the bundled database directly for the user's query
    private func updateDatabaseMatches(query: String) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard normalizedQuery.count >= 3 else {
            databaseMatches = []
            return
        }

        let matches = database.allCourses.filter { course in
            course.name.lowercased().contains(normalizedQuery)
        }
        databaseMatches = Array(matches.prefix(5))
    }

    /// Select a database match, enriching with API tee box data when available.
    /// The database hole/par data is always used as the source of truth.
    func selectDatabaseCourse(_ course: CourseData) async {
        isSearching = true

        // The database has reliable par/hole data — use it as the base.
        // Only fetch from API to supplement with additional tee box details.
        var resolvedData = course

        let apiData = await GolfCourseAPIService.shared.findCourse(
            name: course.name, city: course.city, state: course.state
        )
        if let apiData = apiData, let apiTeeBoxes = apiData.teeBoxes, !apiTeeBoxes.isEmpty {
            // Keep database holes/pars (reliable), add API tee boxes only
            resolvedData = CourseData(
                name: course.name,
                city: course.city,
                state: course.state,
                slopeRating: course.slopeRating,
                courseRating: course.courseRating,
                holes: course.holes,
                teeBoxes: apiTeeBoxes
            )
        }

        let result = CourseSearchResult(
            name: resolvedData.name,
            city: resolvedData.city,
            state: resolvedData.state,
            latitude: 0,
            longitude: 0,
            courseData: resolvedData
        )
        selectedResult = result
        isAutoFilled = true
        searchText = resolvedData.name
        suggestions = []
        databaseMatches = []
        isSearching = false
    }

    /// Select a suggestion and resolve its full details.
    func selectSuggestion(_ completion: MKLocalSearchCompletion) async {
        isSearching = true

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else {
                isSearching = false
                return
            }

            let placemark = item.placemark
            let name = item.name ?? completion.title
            let city = placemark.locality ?? ""
            let state = placemark.administrativeArea ?? ""
            let lat = placemark.coordinate.latitude
            let lon = placemark.coordinate.longitude

            // Try the bundled database FIRST — hand-curated data is more reliable
            var courseData = database.findCourse(name: name, city: city, state: state)

            // Fall back to live API only if database has no match
            if courseData == nil {
                courseData = await GolfCourseAPIService.shared.findCourse(name: name, city: city, state: state)
            }

            let result = CourseSearchResult(
                name: name,
                city: city,
                state: state,
                latitude: lat,
                longitude: lon,
                courseData: courseData
            )

            selectedResult = result
            isAutoFilled = true
            searchText = name
            suggestions = []
        } catch {
            print("⚠️ Course search failed: \(error.localizedDescription)")
            searchError = "Course search failed. Check your connection and try again."
        }

        isSearching = false
    }

    /// Clear the search and selected result.
    func reset() {
        searchText = ""
        suggestions = []
        selectedResult = nil
        isSearching = false
    }
}

// MARK: - MKLocalSearchCompleterDelegate

extension GolfCourseSearchService: MKLocalSearchCompleterDelegate {

    /// Keywords that indicate a MapKit result is a golf course.
    /// Kept strict to avoid surfacing hotels, inns, restaurants, etc.
    private nonisolated static let golfKeywords: [String] = [
        "golf", "country club", "links", "course",
        "tpc", "club at"
    ]

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let keywords = Self.golfKeywords

        // Only show results whose title or subtitle contain golf-specific keywords.
        // Non-golf POIs (hotels, inns, restaurants) are filtered out.
        // The bundled database section in the UI catches courses MapKit misses.
        let results = completer.results.filter { completion in
            let combined = (completion.title + " " + completion.subtitle).lowercased()
            return keywords.contains { combined.contains($0) }
        }

        let finalResults = Array(results.prefix(8))
        Task { @MainActor in
            self.suggestions = finalResults
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

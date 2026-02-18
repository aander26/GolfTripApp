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

    var searchText: String = "" {
        didSet {
            if searchText.count >= 2 {
                completer.queryFragment = searchText
            } else {
                suggestions = []
            }
            // Reset selection when search text changes manually
            if !isAutoFilled {
                selectedResult = nil
            }
            isAutoFilled = false
        }
    }

    var suggestions: [MKLocalSearchCompletion] = []
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

            // Check bundled database for detailed course data
            let courseData = database.findCourse(name: name, city: city, state: state)

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
            // Search failed — clear state
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

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.filter { completion in
            // Filter for golf-related results
            let title = completion.title.lowercased()
            let subtitle = completion.subtitle.lowercased()
            let combined = title + " " + subtitle
            return combined.contains("golf") ||
                   combined.contains("country club") ||
                   combined.contains("links") ||
                   combined.contains("course") ||
                   combined.contains("tpc") ||
                   combined.contains("club at") ||
                   combined.contains("national") ||
                   combined.contains("resort")
        }

        Task { @MainActor in
            self.suggestions = Array(results.prefix(8))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}

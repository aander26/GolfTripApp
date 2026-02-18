import Foundation

@Observable
class WeatherViewModel {
    var appState: AppState

    var currentWeather: WeatherData?
    var forecast: WeatherForecast?
    var isLoading = false
    var errorMessage: String?
    var selectedCourseId: UUID?

    init(appState: AppState) {
        self.appState = appState
    }

    var currentTrip: Trip? { appState.currentTrip }

    var selectedCourse: Course? {
        guard let id = selectedCourseId ?? currentTrip?.courses.first?.id else { return nil }
        return currentTrip?.course(withId: id)
    }

    // MARK: - Fetch Weather

    func fetchWeather() async {
        guard let course = selectedCourse,
              let lat = course.latitude,
              let lon = course.longitude else {
            // Use default location if no course coordinates
            await fetchWeatherForLocation(latitude: 33.45, longitude: -111.95) // Default: Scottsdale, AZ
            return
        }
        await fetchWeatherForLocation(latitude: lat, longitude: lon)
    }

    func fetchWeatherForLocation(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil

        do {
            async let weather = WeatherService.shared.fetchCurrentWeather(latitude: latitude, longitude: longitude)
            async let forecastData = WeatherService.shared.fetchForecast(latitude: latitude, longitude: longitude)

            currentWeather = try await weather
            forecast = try await forecastData
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func setAPIKey(_ key: String) async {
        await WeatherService.shared.setAPIKey(key)
    }

    var playabilityText: String {
        guard let weather = currentWeather else { return "No data" }
        return weather.playabilityRating.rawValue
    }

    var coursesWithLocations: [Course] {
        currentTrip?.courses.filter { $0.latitude != nil && $0.longitude != nil } ?? []
    }
}

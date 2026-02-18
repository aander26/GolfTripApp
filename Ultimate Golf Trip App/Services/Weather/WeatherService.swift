import Foundation

actor WeatherService {
    static let shared = WeatherService()

    // Users should set their own API key — persisted in UserDefaults
    private var apiKey: String = ""
    private let baseURL = "https://api.openweathermap.org/data/2.5"
    private var cache: [String: (data: WeatherData, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 600 // 10 minutes
    private let apiKeyStorageKey = "WeatherService.apiKey"

    private init() {
        // Restore saved API key on launch
        if let savedKey = UserDefaults.standard.string(forKey: apiKeyStorageKey), !savedKey.isEmpty {
            apiKey = savedKey
        }
    }

    func setAPIKey(_ key: String) {
        apiKey = key
        UserDefaults.standard.set(key, forKey: apiKeyStorageKey)
    }

    // MARK: - Current Weather

    func fetchCurrentWeather(latitude: Double, longitude: Double) async throws -> WeatherData {
        let cacheKey = "\(latitude),\(longitude)"
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            return cached.data
        }

        guard !apiKey.isEmpty else {
            return WeatherData() // Return default data if no API key
        }

        let urlString = "\(baseURL)/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        let weather = try parseCurrentWeather(data: data)
        cache[cacheKey] = (data: weather, timestamp: Date())
        return weather
    }

    // MARK: - Forecast

    func fetchForecast(latitude: Double, longitude: Double) async throws -> WeatherForecast {
        guard !apiKey.isEmpty else {
            return WeatherForecast(hourly: [], daily: [])
        }

        let urlString = "\(baseURL)/forecast?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=imperial"
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        return try parseForecast(data: data)
    }

    // MARK: - Parsing

    private func parseCurrentWeather(data: Data) throws -> WeatherData {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WeatherError.parsingError
        }

        let main = json["main"] as? [String: Any] ?? [:]
        let wind = json["wind"] as? [String: Any] ?? [:]
        let weatherArray = json["weather"] as? [[String: Any]] ?? []
        let weatherInfo = weatherArray.first ?? [:]
        let sys = json["sys"] as? [String: Any] ?? [:]

        let condition = mapCondition(id: weatherInfo["id"] as? Int ?? 800)

        return WeatherData(
            temperature: main["temp"] as? Double ?? 72,
            feelsLike: main["feels_like"] as? Double ?? 72,
            humidity: main["humidity"] as? Int ?? 50,
            windSpeed: wind["speed"] as? Double ?? 0,
            windDirection: wind["deg"] as? Int ?? 0,
            windGust: wind["gust"] as? Double,
            condition: condition,
            description: weatherInfo["description"] as? String ?? "",
            icon: weatherInfo["icon"] as? String ?? "01d",
            visibility: json["visibility"] as? Int ?? 10000,
            precipitationChance: 0,
            uvIndex: 0,
            sunrise: (sys["sunrise"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            sunset: (sys["sunset"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) },
            fetchedAt: Date()
        )
    }

    private func parseForecast(data: Data) throws -> WeatherForecast {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["list"] as? [[String: Any]] else {
            throw WeatherError.parsingError
        }

        var hourly: [HourlyForecast] = []
        var dailyMap: [String: (highs: [Double], lows: [Double], conditions: [WeatherCondition], precip: [Double], wind: [Double], desc: String)] = [:]

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"

        for item in list {
            let dt = item["dt"] as? TimeInterval ?? 0
            let time = Date(timeIntervalSince1970: dt)
            let main = item["main"] as? [String: Any] ?? [:]
            let wind = item["wind"] as? [String: Any] ?? [:]
            let weatherArray = item["weather"] as? [[String: Any]] ?? []
            let weatherInfo = weatherArray.first ?? [:]
            let pop = item["pop"] as? Double ?? 0

            let condition = mapCondition(id: weatherInfo["id"] as? Int ?? 800)
            let temp = main["temp"] as? Double ?? 72

            // Add to hourly (first 24 entries = ~3 days)
            if hourly.count < 24 {
                hourly.append(HourlyForecast(
                    time: time,
                    temperature: temp,
                    condition: condition,
                    precipitationChance: pop,
                    windSpeed: wind["speed"] as? Double ?? 0
                ))
            }

            // Aggregate for daily
            let dayKey = dayFormatter.string(from: time)
            var existing = dailyMap[dayKey] ?? (highs: [], lows: [], conditions: [], precip: [], wind: [], desc: "")
            existing.highs.append(temp)
            existing.lows.append(main["temp_min"] as? Double ?? temp)
            existing.conditions.append(condition)
            existing.precip.append(pop)
            existing.wind.append(wind["speed"] as? Double ?? 0)
            if existing.desc.isEmpty {
                existing.desc = weatherInfo["description"] as? String ?? ""
            }
            dailyMap[dayKey] = existing
        }

        let daily: [DailyForecast] = Array(dailyMap.sorted { $0.key < $1.key }.prefix(5)).compactMap { key, value -> DailyForecast? in
            guard let date = dayFormatter.date(from: key) else { return nil }
            let primaryCondition = value.conditions.first ?? .clear

            return DailyForecast(
                date: date,
                highTemp: value.highs.max() ?? 72,
                lowTemp: value.lows.min() ?? 60,
                condition: primaryCondition,
                precipitationChance: value.precip.max() ?? 0,
                windSpeed: value.wind.max() ?? 0,
                description: value.desc
            )
        }

        return WeatherForecast(hourly: hourly, daily: daily)
    }

    private func mapCondition(id: Int) -> WeatherCondition {
        switch id {
        case 200...232: return .thunderstorm
        case 300...321: return .drizzle
        case 500...531: return .rain
        case 600...622: return .snow
        case 701...781: return .fog
        case 801: return .fewClouds
        case 802: return .scattered
        case 803...804: return .cloudy
        default: return .clear
        }
    }
}

enum WeatherError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid weather URL"
        case .invalidResponse: return "Invalid response from weather service"
        case .parsingError: return "Failed to parse weather data"
        case .noAPIKey: return "No API key configured"
        }
    }
}

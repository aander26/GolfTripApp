import Foundation

struct WeatherData: Codable, Hashable, Sendable {
    var temperature: Double
    var feelsLike: Double
    var humidity: Int
    var windSpeed: Double
    var windDirection: Int
    var windGust: Double?
    var condition: WeatherCondition
    var description: String
    var icon: String
    var visibility: Int
    var precipitationChance: Double
    var uvIndex: Double
    var sunrise: Date?
    var sunset: Date?
    var fetchedAt: Date

    init(
        temperature: Double = 72,
        feelsLike: Double = 72,
        humidity: Int = 50,
        windSpeed: Double = 5,
        windDirection: Int = 180,
        windGust: Double? = nil,
        condition: WeatherCondition = .clear,
        description: String = "Clear sky",
        icon: String = "01d",
        visibility: Int = 10000,
        precipitationChance: Double = 0,
        uvIndex: Double = 5,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        fetchedAt: Date = Date()
    ) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.windGust = windGust
        self.condition = condition
        self.description = description
        self.icon = icon
        self.visibility = visibility
        self.precipitationChance = precipitationChance
        self.uvIndex = uvIndex
        self.sunrise = sunrise
        self.sunset = sunset
        self.fetchedAt = fetchedAt
    }

    var temperatureFormatted: String {
        "\(Int(temperature))°F"
    }

    var feelsLikeFormatted: String {
        "\(Int(feelsLike))°F"
    }

    var windFormatted: String {
        "\(Int(windSpeed)) mph \(windDirectionText)"
    }

    var windDirectionText: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(windDirection) + 11.25) / 22.5) % 16
        return directions[index]
    }

    var playabilityRating: PlayabilityRating {
        if condition == .thunderstorm || windSpeed > 30 {
            return .unplayable
        }
        if condition == .rain || windSpeed > 20 || temperature < 40 || temperature > 105 {
            return .poor
        }
        if condition == .drizzle || windSpeed > 15 || temperature < 50 || temperature > 95 {
            return .fair
        }
        if windSpeed > 10 || temperature < 60 || temperature > 90 || humidity > 85 {
            return .good
        }
        return .excellent
    }

    var systemIconName: String {
        switch condition {
        case .clear: return "sun.max.fill"
        case .fewClouds: return "cloud.sun.fill"
        case .scattered: return "cloud.fill"
        case .cloudy: return "smoke.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.rain.fill"
        case .thunderstorm: return "cloud.bolt.rain.fill"
        case .snow: return "cloud.snow.fill"
        case .fog: return "cloud.fog.fill"
        }
    }
}

enum WeatherCondition: String, Codable {
    case clear = "Clear"
    case fewClouds = "Few Clouds"
    case scattered = "Scattered Clouds"
    case cloudy = "Cloudy"
    case drizzle = "Drizzle"
    case rain = "Rain"
    case thunderstorm = "Thunderstorm"
    case snow = "Snow"
    case fog = "Fog"
}

enum PlayabilityRating: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unplayable = "Unplayable"

    var emoji: String {
        switch self {
        case .excellent: return "⛳️"
        case .good: return "👍"
        case .fair: return "🤔"
        case .poor: return "😬"
        case .unplayable: return "🚫"
        }
    }
}

struct WeatherForecast: Codable, Hashable {
    var hourly: [HourlyForecast]
    var daily: [DailyForecast]
}

struct HourlyForecast: Identifiable, Codable, Hashable {
    var id: Date { time }
    var time: Date
    var temperature: Double
    var condition: WeatherCondition
    var precipitationChance: Double
    var windSpeed: Double

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: time).lowercased()
    }
}

struct DailyForecast: Identifiable, Codable, Hashable {
    var id: Date { date }
    var date: Date
    var highTemp: Double
    var lowTemp: Double
    var condition: WeatherCondition
    var precipitationChance: Double
    var windSpeed: Double
    var description: String

    var dayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

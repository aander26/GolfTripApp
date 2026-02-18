import SwiftUI

struct WeatherView: View {
    @Bindable var viewModel: WeatherViewModel
    @State private var apiKey = UserDefaults.standard.string(forKey: "WeatherService.apiKey") ?? ""
    @State private var showingAPIKeyEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let weather = viewModel.currentWeather {
                        currentWeatherCard(weather: weather)
                        playabilityCard(weather: weather)
                        detailsCard(weather: weather)

                        if let forecast = viewModel.forecast {
                            hourlyForecastCard(hourly: forecast.hourly)
                            dailyForecastCard(daily: forecast.daily)
                        }
                    } else if viewModel.isLoading {
                        ProgressView("Loading weather...")
                            .padding(.top, 100)
                    } else {
                        noWeatherView
                    }
                }
                .padding()
            }
            .navigationTitle("Weather")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAPIKeyEntry = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.fetchWeather() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert("OpenWeatherMap API Key", isPresented: $showingAPIKeyEntry) {
                TextField("API Key", text: $apiKey)
                Button("Save") {
                    Task { await viewModel.setAPIKey(apiKey) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your OpenWeatherMap API key to get live weather data. Get a free key at openweathermap.org")
            }
            .task {
                if viewModel.currentWeather == nil {
                    await viewModel.fetchWeather()
                }
            }
        }
    }

    // MARK: - Current Weather Card

    private func currentWeatherCard(weather: WeatherData) -> some View {
        VStack(spacing: 12) {
            // Course name
            if let course = viewModel.selectedCourse {
                Text(course.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Image(systemName: weather.systemIconName)
                .font(.system(size: 56))
                .foregroundStyle(Theme.primary)

            Text(weather.temperatureFormatted)
                .font(.system(size: 52, weight: .thin))

            Text(weather.description.capitalized)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Feels like \(weather.feelsLikeFormatted)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Playability Card

    private func playabilityCard(weather: WeatherData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Golf Playability")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(weather.playabilityRating.rawValue)
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Spacer()

            Text(weather.playabilityRating.emoji)
                .font(.system(size: 40))
        }
        .padding()
        .background(playabilityColor(weather.playabilityRating).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func playabilityColor(_ rating: PlayabilityRating) -> Color {
        switch rating {
        case .excellent: return .green
        case .good: return .green
        case .fair: return .yellow
        case .poor: return .orange
        case .unplayable: return .red
        }
    }

    // MARK: - Details Card

    private func detailsCard(weather: WeatherData) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            weatherDetailItem(icon: "wind", label: "Wind", value: weather.windFormatted)
            weatherDetailItem(icon: "humidity", label: "Humidity", value: "\(weather.humidity)%")
            weatherDetailItem(icon: "cloud.rain", label: "Precip", value: "\(Int(weather.precipitationChance * 100))%")
            weatherDetailItem(icon: "eye", label: "Visibility", value: "\(weather.visibility / 1000)km")

            if let gust = weather.windGust {
                weatherDetailItem(icon: "wind", label: "Gusts", value: "\(Int(gust)) mph")
            }

            weatherDetailItem(icon: "sun.max", label: "UV Index", value: "\(Int(weather.uvIndex))")
        }
    }

    private func weatherDetailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Hourly Forecast

    private func hourlyForecastCard(hourly: [HourlyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hourly Forecast")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(hourly) { hour in
                        VStack(spacing: 6) {
                            Text(hour.timeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Image(systemName: iconForCondition(hour.condition))
                                .font(.title3)
                                .foregroundStyle(Theme.primary)

                            Text("\(Int(hour.temperature))°")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if hour.precipitationChance > 0.1 {
                                Text("\(Int(hour.precipitationChance * 100))%")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Daily Forecast

    private func dailyForecastCard(daily: [DailyForecast]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Forecast")
                .font(.headline)

            ForEach(daily) { day in
                HStack {
                    Text(day.dayFormatted)
                        .font(.subheadline)
                        .frame(width: 40, alignment: .leading)

                    Image(systemName: iconForCondition(day.condition))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 30)

                    if day.precipitationChance > 0.1 {
                        Text("\(Int(day.precipitationChance * 100))%")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .frame(width: 35)
                    } else {
                        Text("")
                            .frame(width: 35)
                    }

                    Spacer()

                    Text("\(Int(day.highTemp))°")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("\(Int(day.lowTemp))°")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                if day.id != daily.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - No Weather

    private var noWeatherView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "cloud.sun")
                .font(.system(size: 60))
                .foregroundStyle(Theme.primary)

            Text("Weather Data")
                .font(.title2)
                .fontWeight(.bold)

            Text("Set up your OpenWeatherMap API key to see live weather for your golf courses.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingAPIKeyEntry = true
            } label: {
                Label("Set API Key", systemImage: "key.fill")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
            }
            .buttonStyle(BoldPrimaryButtonStyle())

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
    }

    private func iconForCondition(_ condition: WeatherCondition) -> String {
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

#Preview {
    WeatherView(viewModel: SampleData.makeWeatherViewModel())
}

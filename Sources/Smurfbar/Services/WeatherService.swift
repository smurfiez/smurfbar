import Foundation
import Combine
import AppKit

// MARK: - Open-Meteo & IP Geolocation Decodables

private struct IPLocationResponse: Codable {
    let status: String?
    let city: String?
    let lat: Double?
    let lon: Double?
}

private struct GeocodingResponse: Codable {
    struct Result: Codable {
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
    }
    let results: [Result]?
}

private struct OpenMeteoResponse: Codable {
    struct Current: Codable {
        let time: String
        let temperature_2m: Double
        let relative_humidity_2m: Int
        let apparent_temperature: Double
        let is_day: Int
        let precipitation: Double
        let weather_code: Int
        let wind_speed_10m: Double
    }

    struct Hourly: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let weather_code: [Int]
    }

    struct Daily: Codable {
        let time: [String]
        let weather_code: [Int]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let precipitation_probability_max: [Int]?
    }

    let latitude: Double
    let longitude: Double
    let current: Current
    let hourly: Hourly?
    let daily: Daily?
}

/// Manages fetching and refreshing weather forecasts via Open-Meteo.
public class WeatherService: ObservableObject {
    public static let shared = WeatherService()

    @Published public var currentWeather: WeatherSnapshot?
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var resolvedCityName: String = "Detecting location..."

    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: AnyCancellable?

    private var cachedLat: Double = 37.7749
    private var cachedLon: Double = -122.4194

    private init() {
        // Refresh every 30 minutes
        refreshTimer = Timer.publish(every: 1800, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchWeather()
            }

        // Listen for preference changes
        PreferencesService.shared.$weatherLocationMode
            .dropFirst()
            .sink { [weak self] _ in
                self?.fetchWeather()
            }
            .store(in: &cancellables)

        PreferencesService.shared.$weatherCustomCity
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                if PreferencesService.shared.weatherLocationMode == .manual {
                    self?.fetchWeather()
                }
            }
            .store(in: &cancellables)

        // Initial fetch after brief delay to avoid startup bottleneck
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.fetchWeather()
        }
    }

    /// Refresh weather information
    public func fetchWeather() {
        guard !isLoading else { return }

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        let prefs = PreferencesService.shared
        if prefs.weatherLocationMode == .manual && !prefs.weatherCustomCity.trimmingCharacters(in: .whitespaces).isEmpty {
            geocodeCityAndFetchWeather(cityName: prefs.weatherCustomCity.trimmingCharacters(in: .whitespaces))
        } else {
            resolveIPAndFetchWeather()
        }
    }

    // MARK: - IP Geolocation

    private func resolveIPAndFetchWeather() {
        guard let url = URL(string: "http://ip-api.com/json") else {
            fetchForecast(lat: cachedLat, lon: cachedLon, cityName: "Local")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let data = data,
               let ipResp = try? JSONDecoder().decode(IPLocationResponse.self, from: data),
               let lat = ipResp.lat, let lon = ipResp.lon {
                let city = ipResp.city ?? "My Location"
                self.cachedLat = lat
                self.cachedLon = lon
                self.fetchForecast(lat: lat, lon: lon, cityName: city)
            } else {
                // Fallback to cached or default
                self.fetchForecast(lat: self.cachedLat, lon: self.cachedLon, cityName: "Local")
            }
        }.resume()
    }

    // MARK: - Geocoding City Search

    private func geocodeCityAndFetchWeather(cityName: String) {
        guard let encodedCity = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCity)&count=1&language=en&format=json") else {
            resolveIPAndFetchWeather()
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            if let data = data,
               let geoResp = try? JSONDecoder().decode(GeocodingResponse.self, from: data),
               let first = geoResp.results?.first {
                self.cachedLat = first.latitude
                self.cachedLon = first.longitude
                self.fetchForecast(lat: first.latitude, lon: first.longitude, cityName: first.name)
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "City '\(cityName)' not found"
                }
            }
        }.resume()
    }

    // MARK: - Open-Meteo Forecast Query

    private func fetchForecast(lat: Double, lon: Double, cityName: String) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=7"

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Invalid weather URL"
            }
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

                    // Parse hourly items (next 24 hours)
                    var hourlyItems: [HourlyForecastItem] = []
                    let isoFormatter = ISO8601DateFormatter()
                    isoFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

                    let now = Date()
                    if let hourly = decoded.hourly {
                        for i in 0..<min(hourly.time.count, hourly.temperature_2m.count) {
                            let timeStr = hourly.time[i]
                            // Open-Meteo provides "2026-09-16T14:00"
                            let parsedDate = isoFormatter.date(from: timeStr) ?? Date()
                            // Keep next 24 hours starting around current hour
                            if parsedDate >= now.addingTimeInterval(-3600) && hourlyItems.count < 24 {
                                let item = HourlyForecastItem(
                                    time: timeStr,
                                    date: parsedDate,
                                    tempCelsius: hourly.temperature_2m[i],
                                    weatherCode: i < hourly.weather_code.count ? hourly.weather_code[i] : 0
                                )
                                hourlyItems.append(item)
                            }
                        }
                    }

                    // Parse daily items (7 days)
                    var dailyItems: [DailyForecastItem] = []
                    let dayFormatter = DateFormatter()
                    dayFormatter.dateFormat = "yyyy-MM-dd"

                    var todayHigh = decoded.current.temperature_2m
                    var todayLow = decoded.current.temperature_2m

                    if let daily = decoded.daily {
                        for i in 0..<daily.time.count {
                            let dateStr = daily.time[i]
                            let parsedDate = dayFormatter.date(from: dateStr) ?? Date()
                            let maxT = i < daily.temperature_2m_max.count ? daily.temperature_2m_max[i] : decoded.current.temperature_2m
                            let minT = i < daily.temperature_2m_min.count ? daily.temperature_2m_min[i] : decoded.current.temperature_2m
                            let code = i < daily.weather_code.count ? daily.weather_code[i] : 0
                            let prob = (daily.precipitation_probability_max != nil && i < daily.precipitation_probability_max!.count) ? (daily.precipitation_probability_max![i]) : 0

                            if i == 0 {
                                todayHigh = maxT
                                todayLow = minT
                            }

                            dailyItems.append(
                                DailyForecastItem(
                                    dateString: dateStr,
                                    date: parsedDate,
                                    minTempCelsius: minT,
                                    maxTempCelsius: maxT,
                                    weatherCode: code,
                                    precipitationProbability: prob
                                )
                            )
                        }
                    }

                    let snapshot = WeatherSnapshot(
                        cityName: cityName,
                        tempCelsius: decoded.current.temperature_2m,
                        apparentTempCelsius: decoded.current.apparent_temperature,
                        weatherCode: decoded.current.weather_code,
                        isDay: decoded.current.is_day == 1,
                        humidity: decoded.current.relative_humidity_2m,
                        windSpeedKmh: decoded.current.wind_speed_10m,
                        precipitationMm: decoded.current.precipitation,
                        highTempCelsius: todayHigh,
                        lowTempCelsius: todayLow,
                        hourly: hourlyItems,
                        daily: dailyItems,
                        lastUpdated: Date()
                    )

                    self.resolvedCityName = cityName
                    self.currentWeather = snapshot
                    self.errorMessage = nil
                } catch {
                    self.errorMessage = "Failed to parse weather: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

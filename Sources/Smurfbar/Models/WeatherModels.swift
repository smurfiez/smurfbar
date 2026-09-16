import Foundation
import SwiftUI

/// Temperature display unit
public enum WeatherUnit: String, CaseIterable, Identifiable, Codable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }

    public var title: String {
        switch self {
        case .celsius: return "Celsius (°C)"
        case .fahrenheit: return "Fahrenheit (°F)"
        }
    }

    public func format(celsius: Double) -> String {
        switch self {
        case .celsius:
            return "\(Int(round(celsius)))°"
        case .fahrenheit:
            let f = (celsius * 9.0 / 5.0) + 32.0
            return "\(Int(round(f)))°"
        }
    }

    public func formatWithSymbol(celsius: Double) -> String {
        return "\(format(celsius: celsius))\(self == .celsius ? "C" : "F")"
    }

    public func formatWindSpeed(kmh: Double) -> String {
        switch self {
        case .celsius:
            return "\(Int(round(kmh))) km/h"
        case .fahrenheit:
            let mph = kmh * 0.621371
            return "\(Int(round(mph))) mph"
        }
    }
}

/// Weather location mode
public enum WeatherLocationMode: String, CaseIterable, Identifiable, Codable {
    case automatic = "automatic"
    case manual = "manual"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic (IP Geolocation)"
        case .manual: return "Custom City"
        }
    }
}

/// Hourly forecast entry
public struct HourlyForecastItem: Identifiable, Codable {
    public var id: String { time }
    public let time: String
    public let date: Date
    public let tempCelsius: Double
    public let weatherCode: Int

    public var hourDisplay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter.string(from: date).lowercased()
    }
}

/// Daily forecast entry
public struct DailyForecastItem: Identifiable, Codable {
    public var id: String { dateString }
    public let dateString: String
    public let date: Date
    public let minTempCelsius: Double
    public let maxTempCelsius: Double
    public let weatherCode: Int
    public let precipitationProbability: Int

    public var dayName: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

/// WMO Weather condition decoder and SF Symbol mapping
public struct WMOWeatherCode {
    public static func condition(for code: Int, isDay: Bool = true) -> (description: String, iconName: String, iconColor: Color) {
        switch code {
        case 0:
            return (
                description: isDay ? "Clear Sky" : "Clear Night",
                iconName: isDay ? "sun.max.fill" : "moon.stars.fill",
                iconColor: isDay ? .yellow : .indigo
            )
        case 1:
            return (
                description: isDay ? "Mainly Clear" : "Mostly Clear",
                iconName: isDay ? "sun.haze.fill" : "moon.stars.fill",
                iconColor: isDay ? .orange : .indigo
            )
        case 2:
            return (
                description: "Partly Cloudy",
                iconName: isDay ? "cloud.sun.fill" : "cloud.moon.fill",
                iconColor: isDay ? .cyan : .gray
            )
        case 3:
            return (
                description: "Overcast",
                iconName: "cloud.fill",
                iconColor: .gray
            )
        case 45, 48:
            return (
                description: "Foggy",
                iconName: "cloud.fog.fill",
                iconColor: .secondary
            )
        case 51, 53, 55:
            return (
                description: "Drizzle",
                iconName: "cloud.drizzle.fill",
                iconColor: .teal
            )
        case 56, 57:
            return (
                description: "Freezing Drizzle",
                iconName: "cloud.sleet.fill",
                iconColor: .cyan
            )
        case 61:
            return (
                description: "Light Rain",
                iconName: "cloud.rain.fill",
                iconColor: .blue
            )
        case 63:
            return (
                description: "Rain",
                iconName: "cloud.rain.fill",
                iconColor: .blue
            )
        case 65:
            return (
                description: "Heavy Rain",
                iconName: "cloud.heavyrain.fill",
                iconColor: .indigo
            )
        case 66, 67:
            return (
                description: "Freezing Rain",
                iconName: "cloud.sleet.fill",
                iconColor: .cyan
            )
        case 71, 73:
            return (
                description: "Snow",
                iconName: "cloud.snow.fill",
                iconColor: .white
            )
        case 75:
            return (
                description: "Heavy Snow",
                iconName: "snowflake",
                iconColor: .white
            )
        case 77:
            return (
                description: "Snow Grains",
                iconName: "snowflake",
                iconColor: .white
            )
        case 80, 81:
            return (
                description: "Showers",
                iconName: isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill",
                iconColor: .blue
            )
        case 82:
            return (
                description: "Heavy Showers",
                iconName: "cloud.heavyrain.fill",
                iconColor: .indigo
            )
        case 85, 86:
            return (
                description: "Snow Showers",
                iconName: "cloud.snow.fill",
                iconColor: .white
            )
        case 95:
            return (
                description: "Thunderstorm",
                iconName: "cloud.bolt.rain.fill",
                iconColor: .yellow
            )
        case 96, 99:
            return (
                description: "Severe Thunderstorm",
                iconName: "cloud.bolt.rain.fill",
                iconColor: .purple
            )
        default:
            return (
                description: "Fair",
                iconName: "cloud.sun.fill",
                iconColor: .orange
            )
        }
    }
}

/// Full Weather Snapshot Model
public struct WeatherSnapshot: Identifiable {
    public var id: String { "\(cityName)-\(lastUpdated.timeIntervalSince1970)" }
    public let cityName: String
    public let tempCelsius: Double
    public let apparentTempCelsius: Double
    public let weatherCode: Int
    public let isDay: Bool
    public let humidity: Int
    public let windSpeedKmh: Double
    public let precipitationMm: Double
    public let highTempCelsius: Double
    public let lowTempCelsius: Double
    public let hourly: [HourlyForecastItem]
    public let daily: [DailyForecastItem]
    public let lastUpdated: Date

    public var condition: (description: String, iconName: String, iconColor: Color) {
        WMOWeatherCode.condition(for: weatherCode, isDay: isDay)
    }
}

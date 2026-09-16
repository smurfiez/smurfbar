import SwiftUI
import AppKit

/// Taskbar Weather & News Glance pill widget.
struct WeatherWidgetView: View {
    @ObservedObject var weatherService = WeatherService.shared
    @ObservedObject var prefs = PreferencesService.shared
    var screen: NSScreen? = nil

    @State private var isHovered: Bool = false

    var body: some View {
        if prefs.showWeatherWidget {
            Button(action: {
                let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
                if let targetScreen = targetScreen {
                    WeatherWindowController.shared.toggle(relativeTo: targetScreen)
                }
            }) {
                Group {
                    if prefs.taskbarPosition.isVertical {
                        verticalContent
                    } else {
                        horizontalContent
                    }
                }
                .padding(.horizontal, prefs.taskbarPosition.isVertical ? 4 : 8)
                .padding(.vertical, 4)
                .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(tooltipText)
            .onHover { isHovered = $0 }
        }
    }

    // MARK: - Layouts

    private var horizontalContent: some View {
        HStack(spacing: 6) {
            if let weather = weatherService.currentWeather {
                Image(systemName: weather.condition.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(weather.condition.iconColor)

                Text(prefs.weatherUnit.format(celsius: weather.tempCelsius))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                if !prefs.compactMode {
                    Text(weather.condition.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else if weatherService.isLoading {
                ProgressView()
                    .controlSize(.mini)
                Text("Weather...")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text("--°")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var verticalContent: some View {
        VStack(spacing: 2) {
            if let weather = weatherService.currentWeather {
                Image(systemName: weather.condition.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(weather.condition.iconColor)

                Text(prefs.weatherUnit.format(celsius: weather.tempCelsius))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            } else {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var tooltipText: String {
        if let weather = weatherService.currentWeather {
            return "\(weather.cityName): \(weather.condition.description), \(prefs.weatherUnit.formatWithSymbol(celsius: weather.tempCelsius))\nClick for full forecast"
        } else if weatherService.isLoading {
            return "Loading weather forecast..."
        } else {
            return "Weather unavailable. Click to retry."
        }
    }
}

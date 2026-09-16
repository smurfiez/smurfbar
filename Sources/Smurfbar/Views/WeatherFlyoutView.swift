import SwiftUI
import AppKit

/// Windows 11 style Weather & Forecast flyout view.
struct WeatherFlyoutView: View {
    @ObservedObject var weatherService = WeatherService.shared
    @ObservedObject var prefs = PreferencesService.shared
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Header
            headerSection

            if let weather = weatherService.currentWeather {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Hero current weather
                        heroSection(weather: weather)

                        // Weather detail cards
                        metricsSection(weather: weather)

                        // Hourly strip
                        if !weather.hourly.isEmpty {
                            hourlySection(weather: weather)
                        }

                        // 7-day forecast
                        if !weather.daily.isEmpty {
                            dailySection(weather: weather)
                        }

                        // Attribution
                        footerSection
                    }
                    .padding(.bottom, 8)
                }
            } else if weatherService.isLoading {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Fetching weather forecast...")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "cloud.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text(weatherService.errorMessage ?? "Weather data unavailable")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    Button("Retry") {
                        weatherService.fetchWeather()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(16)
        .frame(width: 360, height: 480)
        .background(
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)

                    Text(weatherService.currentWeather?.cityName ?? weatherService.resolvedCityName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                if let weather = weatherService.currentWeather {
                    Text(weather.condition.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: {
                    weatherService.fetchWeather()
                }) {
                    if weatherService.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Refresh Weather")
                .disabled(weatherService.isLoading)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Close")
            }
        }
    }

    // MARK: - Hero Current Weather

    private func heroSection(weather: WeatherSnapshot) -> some View {
        HStack(spacing: 16) {
            Image(systemName: weather.condition.iconName)
                .font(.system(size: 44))
                .foregroundColor(weather.condition.iconColor)
                .shadow(color: weather.condition.iconColor.opacity(0.3), radius: 6, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(prefs.weatherUnit.format(celsius: weather.tempCelsius))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(prefs.weatherUnit.symbol)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text("H: \(prefs.weatherUnit.format(celsius: weather.highTempCelsius))")
                    Text("L: \(prefs.weatherUnit.format(celsius: weather.lowTempCelsius))")
                    Text("•")
                    Text("Feels like \(prefs.weatherUnit.format(celsius: weather.apparentTempCelsius))")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.05)))
    }

    // MARK: - Metrics

    private func metricsSection(weather: WeatherSnapshot) -> some View {
        HStack(spacing: 8) {
            metricCard(
                icon: "humidity.fill",
                iconColor: .cyan,
                label: "Humidity",
                value: "\(weather.humidity)%"
            )

            metricCard(
                icon: "wind",
                iconColor: .teal,
                label: "Wind",
                value: prefs.weatherUnit.formatWindSpeed(kmh: weather.windSpeedKmh)
            )

            metricCard(
                icon: "drop.fill",
                iconColor: .blue,
                label: "Precipitation",
                value: "\(String(format: "%.1f", weather.precipitationMm)) mm"
            )
        }
    }

    private func metricCard(icon: String, iconColor: Color, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - Hourly Strip

    private func hourlySection(weather: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOURLY FORECAST")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(weather.hourly) { item in
                        let condition = WMOWeatherCode.condition(for: item.weatherCode, isDay: true)
                        VStack(spacing: 6) {
                            Text(item.hourDisplay)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)

                            Image(systemName: condition.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(condition.iconColor)

                            Text(prefs.weatherUnit.format(celsius: item.tempCelsius))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 42)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.03)))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - 7-Day Forecast

    private func dailySection(weather: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("7-DAY FORECAST")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                ForEach(weather.daily) { day in
                    let condition = WMOWeatherCode.condition(for: day.weatherCode, isDay: true)
                    HStack(spacing: 8) {
                        Text(day.dayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 48, alignment: .leading)

                        Image(systemName: condition.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(condition.iconColor)
                            .frame(width: 22)

                        if day.precipitationProbability > 0 {
                            Text("\(day.precipitationProbability)%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 28, alignment: .trailing)
                        } else {
                            Spacer()
                                .frame(width: 28)
                        }

                        Spacer()

                        Text(prefs.weatherUnit.format(celsius: day.minTempCelsius))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .trailing)

                        // Temperature range visual indicator bar
                        Capsule()
                            .fill(LinearGradient(
                                colors: [.blue.opacity(0.6), .orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: 60, height: 4)

                        Text(prefs.weatherUnit.format(celsius: day.maxTempCelsius))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 28, alignment: .trailing)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.04)))
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("Updated \(timeAgoString(from: weatherService.currentWeather?.lastUpdated ?? Date()))")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                if let url = URL(string: "https://open-meteo.com") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Text("Open-Meteo Weather")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

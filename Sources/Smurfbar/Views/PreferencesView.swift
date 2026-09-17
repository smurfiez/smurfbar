import SwiftUI

/// Preferences window view.
struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesService.shared
    @ObservedObject var pinnedService = PinnedAppsService.shared
    @ObservedObject var screenCaptureService = ScreenCaptureService.shared
    @ObservedObject var updateService = UpdateService.shared
    @ObservedObject var weatherService = WeatherService.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            widgetsTab
                .tabItem {
                    Label("Widgets & Tray", systemImage: "slider.horizontal.below.rectangle")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            pinnedAppsTab
                .tabItem {
                    Label("Pinned Apps", systemImage: "pin")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 530, height: 500)
        .padding()
        .onAppear {
            screenCaptureService.checkPermission()
        }
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    AppIconView(size: 52)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text("Smurfbar")
                                .font(.headline)
                            Text("v\(updateService.currentVersion)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                        }

                        Text("Windows-style taskbar and desktop manager for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 2)
            }

            Section(header: Text("Taskbar Behavior")) {
                Toggle("Launch Smurfbar at Login", isOn: $prefs.launchAtLogin)
                    .help("Automatically start Smurfbar when you log in")

                Toggle("Auto-hide Taskbar", isOn: $prefs.autoHide)
                    .help("Hide the taskbar when the cursor moves away from the edge of the screen")

                Toggle("Compact Taskbar Height", isOn: $prefs.compactMode)
                    .help("Reduce taskbar thickness from 48px to 40px")

                Toggle("Show Application Name Labels", isOn: $prefs.showAppLabels)
                    .help("Display application names alongside icons in the taskbar")

                Picker("Indicator Dots", selection: $prefs.runningIndicatorMode) {
                    ForEach(RunningIndicatorMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .help("Choose when indicator dots appear below application names: only when an app has notifications/needs attention, always for running apps, or never")

                Toggle("Show Live Window Previews", isOn: $prefs.showWindowPreviews)
                    .help("Display window thumbnails when hovering over application tiles")

                Toggle("Enable Window Snapping (Aero Snap)", isOn: $prefs.enableWindowSnapping)
                    .help("Drag windows to screen edges or use Ctrl+Arrow to tile windows")

                if prefs.enableWindowSnapping {
                    Toggle("Show Snap Layouts Drop Bar", isOn: $prefs.enableSnapLayoutsBar)
                        .help("Show Windows 11 Snap Layouts bar at the top of the screen when dragging windows to organize workflows")
                        .padding(.leading, 12)
                }
            }

            Section(header: Text("Grouping & Search")) {
                Picker("Window Grouping", selection: $prefs.windowGroupingMode) {
                    ForEach(WindowGroupingMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Search Widget", selection: $prefs.searchStyle) {
                    ForEach(TaskbarSearchStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Multi-Monitor Mode", selection: $prefs.multiMonitorMode) {
                    ForEach(MultiMonitorMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(16)
    }

    private var widgetsTab: some View {
        Form {
            Section(header: Text("Weather Widget (Windows 11 Glance)")) {
                Toggle("Show Weather Widget", isOn: $prefs.showWeatherWidget)
                    .help("Display real-time weather icon, temperature, and description on the taskbar")

                if prefs.showWeatherWidget {
                    Picker("Temperature Unit", selection: $prefs.weatherUnit) {
                        ForEach(WeatherUnit.allCases) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Location Detection", selection: $prefs.weatherLocationMode) {
                        ForEach(WeatherLocationMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if prefs.weatherLocationMode == .manual {
                        HStack {
                            TextField("City name (e.g. Tokyo, London)", text: $prefs.weatherCustomCity)
                                .textFieldStyle(.roundedBorder)

                            Button("Update") {
                                weatherService.fetchWeather()
                            }
                        }
                    }
                }
            }

            Section(header: Text("Resource Monitor (System Glance)")) {
                Toggle("Show Resource Monitor (CPU & RAM)", isOn: $prefs.showSystemGlance)
                    .help("Display mini live CPU and RAM usage gauge in the system tray")
            }

            Section(header: Text("System Tray Indicators")) {
                Toggle("Show Volume & Audio Control", isOn: $prefs.showVolumeControl)
                    .help("Display volume speaker icon in the system tray")

                Toggle("Show Network (Wi-Fi) Status", isOn: $prefs.showWifiStatus)
                    .help("Display Wi-Fi signal icon in the system tray")

                Toggle("Show Battery Status", isOn: $prefs.showBatteryStatus)
                    .help("Display battery percentage and charge icon in the system tray")
            }

            Section(header: Text("Date, Time & Desktop")) {
                Toggle("Show Clock & Time Display", isOn: $prefs.showClock)
                    .help("Display current time on the taskbar (clicking opens calendar flyout)")

                Toggle("Show Desktop Peek Button", isOn: $prefs.showDesktopPeek)
                    .help("Display thin sliver button on the far edge to show the desktop")
            }
        }
        .padding(16)
    }

    private var appearanceTab: some View {
        Form {
            Section(header: Text("Theme & Layout")) {
                Picker("Theme Mode", selection: $prefs.theme) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Taskbar Position", selection: $prefs.taskbarPosition) {
                    ForEach(TaskbarPosition.allCases) { pos in
                        Text(pos.rawValue).tag(pos)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Item Alignment", selection: $prefs.taskbarAlignment) {
                    ForEach(TaskbarAlignment.allCases) { align in
                        Text(align.rawValue).tag(align)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Styling")) {
                HStack {
                    Text("Opacity: \(Int(prefs.taskbarOpacity * 100))%")
                    Slider(value: $prefs.taskbarOpacity, in: 0.35...1.0)
                }

                Picker("Accent Color", selection: $prefs.accentColorChoice) {
                    ForEach(AccentColorOption.allCases) { opt in
                        HStack {
                            Circle().fill(opt.color).frame(width: 8, height: 8)
                            Text(opt.rawValue)
                        }.tag(opt)
                    }
                }
            }
        }
        .padding(16)
    }

    private var pinnedAppsTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned Applications (\(pinnedService.pinnedApps.count))")
                .font(.headline)

            List {
                ForEach(pinnedService.pinnedApps) { pinned in
                    HStack(spacing: 10) {
                        Image(nsImage: pinned.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)

                        Text(pinned.localizedName)
                            .font(.system(size: 12))

                        Spacer()

                        Button(action: {
                            pinnedService.unpinApp(bundleIdentifier: pinned.bundleIdentifier)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Unpin application")
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.bordered)
        }
        .padding(20)
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            AppIconView(size: 88)

            VStack(spacing: 4) {
                Text("Smurfbar")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Version \(updateService.currentVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A sleek, lightweight Windows-style taskbar and desktop manager for macOS.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Divider()
                .padding(.horizontal, 20)

            // Updates Section
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            if updateService.isChecking {
                                ProgressView()
                                    .controlSize(.small)
                            } else if updateService.updateAvailable {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }

                            Text(updateService.statusMessage)
                                .font(.callout)
                                .fontWeight(.medium)
                        }

                        if let date = updateService.lastCheckedDate {
                            Text("Last checked: \(date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    if updateService.updateAvailable {
                        Button(action: {
                            updateService.downloadAndInstallUpdate()
                        }) {
                            if updateService.isDownloading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Download Update")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(updateService.isDownloading)
                    } else {
                        Button("Check for Updates") {
                            updateService.checkForUpdates(manual: true)
                        }
                        .disabled(updateService.isChecking)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
                .padding(.horizontal, 20)

                // Additional Settings & Links
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Automatically check for updates on launch", isOn: $prefs.autoCheckUpdates)
                        .font(.callout)

                    HStack(spacing: 16) {
                        Button(action: {
                            updateService.openReleasePage()
                        }) {
                            Label("View on GitHub", systemImage: "link")
                                .font(.caption)
                        }
                        .buttonStyle(.link)

                        Button(action: {
                            if let url = URL(string: "https://github.com/smurfiez/smurfbar/issues") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Report Issue", systemImage: "exclamationmark.bubble")
                                .font(.caption)
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.top, 24)
    }
}

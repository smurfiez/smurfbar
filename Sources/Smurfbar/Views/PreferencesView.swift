import SwiftUI

/// Preferences window view.
struct PreferencesView: View {
    @ObservedObject var prefs = PreferencesService.shared
    @ObservedObject var pinnedService = PinnedAppsService.shared
    @ObservedObject var screenCaptureService = ScreenCaptureService.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
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
        .frame(width: 480, height: 350)
        .padding()
        .onAppear {
            screenCaptureService.checkPermission()
        }
    }

    // MARK: - Tabs

    private var generalTab: some View {
        Form {
            Section {
                Toggle("Launch Smurfbar at Login", isOn: $prefs.launchAtLogin)
                    .help("Automatically start Smurfbar when you log in")

                Toggle("Auto-hide Taskbar", isOn: $prefs.autoHide)
                    .help("Hide the taskbar when the cursor moves away from the bottom of the screen")

                Toggle("Compact Taskbar Height", isOn: $prefs.compactMode)
                    .help("Reduce taskbar height from 48px to 40px")

                Toggle("Show Application Name Labels", isOn: $prefs.showAppLabels)
                    .help("Display application names alongside icons in the taskbar")

                Toggle("Show Live Window Previews", isOn: $prefs.showWindowPreviews)
                    .help("Display window thumbnails when hovering over application tiles")

                if prefs.showWindowPreviews && !screenCaptureService.isPermissionGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Screen Recording permission is needed for live previews.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Grant Access") {
                            screenCaptureService.requestPermission()
                            screenCaptureService.openScreenRecordingSettings()
                        }
                        .font(.caption)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(20)
    }

    private var appearanceTab: some View {
        Form {
            Section(header: Text("Taskbar Theme")) {
                Picker("Theme Mode", selection: $prefs.theme) {
                    ForEach(ThemeMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 8)

                Text("System mode uses the native macOS appearance, while Dark and Light force specific translucent materials.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
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
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Smurfbar")
                .font(.title2)
                .fontWeight(.bold)

            Text("Version 0.2.0 (Phase 2)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A sleek, lightweight Windows-style taskbar for macOS.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 30)
    }
}

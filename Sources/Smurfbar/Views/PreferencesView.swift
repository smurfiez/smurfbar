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
        .frame(width: 500, height: 420)
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
                    .help("Hide the taskbar when the cursor moves away from the edge of the screen")

                Toggle("Compact Taskbar Height", isOn: $prefs.compactMode)
                    .help("Reduce taskbar height from 48px to 40px")

                Toggle("Show Application Name Labels", isOn: $prefs.showAppLabels)
                    .help("Display application names alongside icons in the taskbar")

                Toggle("Show Live Window Previews", isOn: $prefs.showWindowPreviews)
                    .help("Display window thumbnails when hovering over application tiles")

                Toggle("Enable Window Snapping (Aero Snap)", isOn: $prefs.enableWindowSnapping)
                    .help("Drag windows to screen edges or use Ctrl+Arrow to tile windows")

                Toggle("Show Overflow Navigation Arrows", isOn: $prefs.showOverflowArrows)
                    .help("Show scroll arrow buttons when there are many open apps")

                Picker("Multi-Monitor Mode", selection: $prefs.multiMonitorMode) {
                    ForEach(MultiMonitorMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)

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
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Smurfbar")
                .font(.title2)
                .fontWeight(.bold)

            Text("Version 0.4.0 (Phase 4)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("A sleek, lightweight Windows-style taskbar and desktop manager for macOS.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 30)
    }
}

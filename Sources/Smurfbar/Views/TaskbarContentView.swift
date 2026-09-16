import SwiftUI
import Combine

/// The main taskbar content view — a horizontal bar containing all app tiles.
/// Hosted inside the TaskbarPanel via NSHostingView.
struct TaskbarContentView: View {
    @ObservedObject var appMonitor: AppMonitor
    @ObservedObject var prefs = PreferencesService.shared
    @ObservedObject var systemStatus = SystemStatusService.shared

    @State private var currentDate: Date = Date()
    @State private var isClockHovered: Bool = false
    @State private var isTrayHovered: Bool = false
    @State private var isShowDesktopHovered: Bool = false
    @State private var isDesktopShown: Bool = false

    private let clockTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 2) {
            // Smurfbar logo / Start menu button
            smurfbarButton

            Divider()
                .frame(height: prefs.compactMode ? 22 : 28)
                .padding(.horizontal, 4)

            // Running & Pinned apps
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(appMonitor.runningApps) { app in
                        AppTileView(
                            app: app,
                            isActive: app.pid != nil && app.pid == appMonitor.activeAppPID,
                            onTap: {
                                handleAppTap(app)
                            },
                            onRightClick: {
                                // Context menu is handled via SwiftUI .contextMenu
                            }
                        )
                        .onHover { hovering in
                            handleAppHover(app: app, hovering: hovering)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            // System area (right side)
            systemArea
        }
        .padding(.horizontal, 8)
        .frame(height: prefs.taskbarHeight)
        .onReceive(clockTimer) { date in
            currentDate = date
        }
    }

    // MARK: - Subviews

    private var smurfbarButton: some View {
        Button(action: {
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                AppLauncherWindowController.shared.toggle(relativeTo: screen) {
                    PreferencesWindowController.shared.showPreferences()
                }
            }
        }) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: prefs.compactMode ? 14 : 16, weight: .medium))
                .foregroundColor(.accentColor)
                .frame(width: prefs.compactMode ? 28 : 32, height: prefs.compactMode ? 28 : 32)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("Smurfbar Menu")
    }

    private var systemArea: some View {
        HStack(spacing: 6) {
            Divider()
                .frame(height: prefs.compactMode ? 20 : 26)

            // System Tray Indicators (Wi-Fi, Volume, Battery)
            systemTrayButtons

            Divider()
                .frame(height: prefs.compactMode ? 18 : 22)

            // Interactive Clock Button
            Button(action: {
                if let screen = NSScreen.main ?? NSScreen.screens.first {
                    CalendarWindowController.shared.toggle(relativeTo: screen)
                }
            }) {
                Text(timeString(from: currentDate))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(isClockHovered ? Color.primary.opacity(0.08) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help(dateString(from: currentDate))
            .onHover { isClockHovered = $0 }

            // Show Desktop Peek Strip (Far Right Edge)
            showDesktopStrip
        }
        .padding(.trailing, 2)
    }

    private var systemTrayButtons: some View {
        Button(action: {
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                QuickSettingsWindowController.shared.toggle(relativeTo: screen) {
                    PreferencesWindowController.shared.showPreferences()
                }
            }
        }) {
            HStack(spacing: 6) {
                // Wi-Fi Icon
                Image(systemName: systemStatus.wifi.iconName)
                    .font(.system(size: 11))
                    .foregroundColor(systemStatus.wifi.isConnected ? .primary : .secondary)

                // Volume Icon
                Image(systemName: volumeTrayIconName)
                    .font(.system(size: 11))
                    .foregroundColor(systemStatus.isMuted ? .secondary : .primary)

                // Battery Icon & Percentage
                HStack(spacing: 3) {
                    Image(systemName: systemStatus.battery.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(systemStatus.battery.percentage < 20 ? .red : .primary)
                    if systemStatus.battery.hasBattery {
                        Text("\(systemStatus.battery.percentage)%")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isTrayHovered ? Color.primary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help("Quick Settings (Volume, Wi-Fi, Battery)")
        .onHover { isTrayHovered = $0 }
    }

    private var volumeTrayIconName: String {
        if systemStatus.isMuted || systemStatus.volume == 0 {
            return "speaker.slash.fill"
        } else if systemStatus.volume < 0.5 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.2.fill"
        }
    }

    private var showDesktopStrip: some View {
        Button(action: {
            toggleShowDesktop()
        }) {
            Rectangle()
                .fill(isShowDesktopHovered ? Color.primary.opacity(0.35) : Color.primary.opacity(0.12))
                .frame(width: 5, height: prefs.compactMode ? 24 : 30)
                .clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .buttonStyle(.plain)
        .help("Show Desktop")
        .onHover { isShowDesktopHovered = $0 }
        .padding(.leading, 2)
    }

    private func toggleShowDesktop() {
        let workspace = NSWorkspace.shared
        if !isDesktopShown {
            for app in workspace.runningApplications {
                if app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    app.hide()
                }
            }
            isDesktopShown = true
        } else {
            for app in workspace.runningApplications {
                if app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    app.unhide()
                }
            }
            isDesktopShown = false
        }
    }

    // MARK: - Time Formatting

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Interaction Handlers

    private func handleAppTap(_ app: RunningApp) {
        // Immediately dismiss any window preview without animation or delay
        WindowPreviewWindowController.shared.closePreview()

        // Toggle activation or launch
        AppActionService.shared.toggleActivation(for: app)
    }

    private func handleAppHover(app: RunningApp, hovering: Bool) {
        let mouseX = NSEvent.mouseLocation.x
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first!
        WindowPreviewWindowController.shared.handleTileHover(
            app: app,
            screenX: mouseX,
            on: screen,
            isHovering: hovering
        )
    }
}

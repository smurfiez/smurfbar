import SwiftUI
import Combine

/// The main taskbar content view — a horizontal bar containing all app tiles.
/// Hosted inside the TaskbarPanel via NSHostingView.
struct TaskbarContentView: View {
    @ObservedObject var appMonitor: AppMonitor
    @ObservedObject var prefs = PreferencesService.shared
    @ObservedObject var systemStatus = SystemStatusService.shared
    var screen: NSScreen? = nil

    @State private var currentDate: Date = Date()
    @State private var isClockHovered: Bool = false
    @State private var isTrayHovered: Bool = false
    @State private var isShowDesktopHovered: Bool = false
    @State private var isDesktopShown: Bool = false

    private let clockTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var visibleApps: [RunningApp] {
        if prefs.multiMonitorMode == .allMonitors {
            return appMonitor.apps(for: screen)
        } else {
            return appMonitor.runningApps
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            // Smurfbar logo / Start menu button
            smurfbarButton

            Divider()
                .frame(height: prefs.compactMode ? 22 : 28)
                .padding(.horizontal, 4)

            if prefs.taskbarAlignment == .center {
                Spacer()
            }

            // Running & Pinned apps with optional overflow controls
            appsSection

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

    private var appsSection: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 2) {
                if prefs.showOverflowArrows && visibleApps.count > 8 {
                    Button(action: {
                        if let first = visibleApps.first {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(first.id, anchor: .leading)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: prefs.compactMode ? 24 : 28)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Scroll to start")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(visibleApps) { app in
                            AppTileView(
                                app: app,
                                isActive: app.pid != nil && app.pid == appMonitor.activeAppPID,
                                onTap: {
                                    handleAppTap(app)
                                },
                                onRightClick: {
                                    // Context menu is handled via SwiftUI .contextMenu
                                },
                                onHover: { hovering in
                                    handleAppHover(app: app, hovering: hovering)
                                }
                            )
                            .id(app.id)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                if prefs.showOverflowArrows && visibleApps.count > 8 {
                    Button(action: {
                        if let last = visibleApps.last {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(last.id, anchor: .trailing)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 16, height: prefs.compactMode ? 24 : 28)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Scroll to end")
                }
            }
        }
    }

    private var smurfbarButton: some View {
        Button(action: {
            let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
            if let targetScreen = targetScreen {
                AppLauncherWindowController.shared.toggle(relativeTo: targetScreen) {
                    PreferencesWindowController.shared.showPreferences()
                }
            }
        }) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: prefs.compactMode ? 14 : 16, weight: .medium))
                .foregroundColor(prefs.accentColorChoice.color)
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
                let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
                if let targetScreen = targetScreen {
                    CalendarWindowController.shared.toggle(relativeTo: targetScreen)
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
            let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
            if let targetScreen = targetScreen {
                QuickSettingsWindowController.shared.toggle(relativeTo: targetScreen) {
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

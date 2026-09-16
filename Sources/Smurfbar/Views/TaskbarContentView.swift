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
    @State private var contentAppsWidth: CGFloat = 0

    private let clockTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var visibleItems: [TaskbarItem] {
        appMonitor.taskbarItems(for: screen)
    }

    private var isAppsOverflowing: Bool {
        guard prefs.showOverflowArrows else { return false }
        let currentScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenWidth = currentScreen?.frame.width ?? 1440

        // Space taken by widgets & system area
        var reservedWidth: CGFloat = 40 // Start button
        if currentScreen != nil {
            switch prefs.searchStyle {
            case .searchBox: reservedWidth += 170
            case .iconOnly: reservedWidth += 40
            case .hidden: break
            }
        }
        if prefs.showWeatherWidget {
            reservedWidth += prefs.compactMode ? 80 : 130
        }
        reservedWidth += 20 // Divider

        if prefs.showSystemGlance {
            reservedWidth += 75
        }
        if prefs.hasSystemTrayIcons {
            reservedWidth += 85
        }
        if prefs.showClock {
            reservedWidth += 90
        }
        if prefs.showDesktopPeek {
            reservedWidth += 15
        }
        reservedWidth += 40 // Margins

        let availableSpace = max(150, screenWidth - reservedWidth)

        if contentAppsWidth > 0 {
            return contentAppsWidth > availableSpace
        }

        // Fallback estimate: 46px per icon button, 140px per labeled/ungrouped button
        let tileWidth: CGFloat = (prefs.showAppLabels || prefs.windowGroupingMode == .neverCombine) ? 140 : 46
        let estimatedTotal = CGFloat(visibleItems.count) * tileWidth
        return estimatedTotal > availableSpace
    }

    var body: some View {
        Group {
            if prefs.taskbarPosition.isVertical {
                verticalLayout
            } else {
                horizontalLayout
            }
        }
        .onReceive(clockTimer) { date in
            currentDate = date
        }
    }

    // MARK: - Layouts

    private var horizontalLayout: some View {
        HStack(spacing: 2) {
            // Smurfbar logo / Start menu button
            smurfbarButton

            // Search widget
            if let scr = screen ?? NSScreen.main ?? NSScreen.screens.first {
                TaskbarSearchBoxView(screen: scr) {
                    PreferencesWindowController.shared.showPreferences()
                }
            }

            // Weather widget (Windows 11 glance)
            WeatherWidgetView(screen: screen)

            Divider()
                .frame(height: prefs.compactMode ? 22 : 28)
                .padding(.horizontal, 3)

            if prefs.taskbarAlignment == .center {
                Spacer()
            }

            // Running & Pinned apps with optional overflow controls
            horizontalAppsSection

            Spacer()

            // System glance resource telemetry meter
            SystemGlanceWidget()

            // System area (right side)
            systemArea
        }
        .padding(.horizontal, 6)
        .frame(height: prefs.taskbarHeight)
    }

    private var verticalLayout: some View {
        VStack(spacing: 6) {
            // Start button at top
            smurfbarButton
                .padding(.top, 4)

            // Search button at top
            if let scr = screen ?? NSScreen.main ?? NSScreen.screens.first {
                TaskbarSearchBoxView(screen: scr) {
                    PreferencesWindowController.shared.showPreferences()
                }
            }

            Divider()
                .frame(width: prefs.compactMode ? 28 : 34)

            // Vertical apps scrollview
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(visibleItems) { item in
                        AppTileView(
                            item: item,
                            isActive: item.pid != nil && item.pid == appMonitor.activeAppPID,
                            onTap: {
                                handleItemTap(item)
                            },
                            onRightClick: {},
                            onHover: { hovering in
                                handleAppHover(app: item.runningApp, hovering: hovering)
                            },
                            onReorder: { sourceID in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    appMonitor.moveItem(sourceID: sourceID, targetID: item.id)
                                }
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.vertical, 2)
            }

            Spacer()

            if prefs.showWeatherWidget || prefs.showSystemGlance || prefs.hasSystemTrayIcons || prefs.showClock {
                Divider()
                    .frame(width: prefs.compactMode ? 28 : 34)
            }

            // Weather widget, System Glance & tray buttons in vertical stack
            WeatherWidgetView(screen: screen)

            SystemGlanceWidget()

            if prefs.hasSystemTrayIcons {
                systemTrayButtons
            }

            // Compact Clock
            if prefs.showClock {
                Button(action: {
                    let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first
                    if let targetScreen = targetScreen {
                        CalendarWindowController.shared.toggle(relativeTo: targetScreen)
                    }
                }) {
                    Text(compactTimeString(from: currentDate))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 6)
            }
        }
        .frame(width: prefs.taskbarThickness)
    }

    // MARK: - Subviews

    private var horizontalAppsSection: some View {
        ScrollViewReader { proxy in
            HStack(spacing: 2) {
                if isAppsOverflowing {
                    Button(action: {
                        if let first = visibleItems.first {
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
                        ForEach(visibleItems) { item in
                            AppTileView(
                                item: item,
                                isActive: item.pid != nil && item.pid == appMonitor.activeAppPID,
                                onTap: {
                                    handleItemTap(item)
                                },
                                onRightClick: {
                                    // Context menu is handled via SwiftUI .contextMenu
                                },
                                onHover: { hovering in
                                    handleAppHover(app: item.runningApp, hovering: hovering)
                                },
                                onReorder: { sourceID in
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appMonitor.moveItem(sourceID: sourceID, targetID: item.id)
                                    }
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.horizontal, 4)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TaskbarAppListWidthKey.self,
                                value: geo.size.width
                            )
                        }
                    )
                }

                if isAppsOverflowing {
                    Button(action: {
                        if let last = visibleItems.last {
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
            .onPreferenceChange(TaskbarAppListWidthKey.self) { measuredWidth in
                if measuredWidth > 0 {
                    contentAppsWidth = measuredWidth
                }
            }
        }
    }

    private var smurfbarButton: some View {
        Button(action: {
            print("🟢 Smurfbar Start button CLICKED!")
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
            if prefs.hasSystemTrayIcons || prefs.showClock {
                Divider()
                    .frame(height: prefs.compactMode ? 20 : 26)
            }

            // System Tray Indicators (Wi-Fi, Volume, Battery)
            if prefs.hasSystemTrayIcons {
                systemTrayButtons
            }

            // Interactive Clock Button
            if prefs.showClock {
                if prefs.hasSystemTrayIcons {
                    Divider()
                        .frame(height: prefs.compactMode ? 18 : 22)
                }

                Button(action: {
                    print("🟢 Clock button CLICKED!")
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
            }

            // Show Desktop Peek Strip (Far Right Edge)
            if prefs.showDesktopPeek {
                showDesktopStrip
            }
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
                if prefs.showWifiStatus {
                    Image(systemName: systemStatus.wifi.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(systemStatus.wifi.isConnected ? .primary : .secondary)
                }

                // Volume Icon
                if prefs.showVolumeControl {
                    Image(systemName: volumeTrayIconName)
                        .font(.system(size: 11))
                        .foregroundColor(systemStatus.isMuted ? .secondary : .primary)
                }

                // Battery Icon & Percentage
                if prefs.showBatteryStatus {
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

    private func compactTimeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm\na"
        return formatter.string(from: date)
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Interaction Handlers

    private func handleItemTap(_ item: TaskbarItem) {
        print("🟢 App/Item CLICKED: \(item.title)")
        WindowPreviewWindowController.shared.closePreview()

        if let win = item.window {
            AppActionService.shared.activateWindow(
                for: item.runningApp,
                windowTitle: win.title,
                windowID: win.windowID
            )
        } else {
            handleAppTap(item.runningApp)
        }
    }

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

/// PreferenceKey to measure actual intrinsic width of all app tiles combined
private struct TaskbarAppListWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

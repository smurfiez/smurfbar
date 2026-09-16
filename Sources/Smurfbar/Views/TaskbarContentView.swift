import SwiftUI
import Combine

/// The main taskbar content view — a horizontal bar containing all app tiles.
/// Hosted inside the TaskbarPanel via NSHostingView.
struct TaskbarContentView: View {
    @ObservedObject var appMonitor: AppMonitor
    @ObservedObject var prefs = PreferencesService.shared

    @State private var hoveredAppPID: pid_t? = nil
    @State private var hoverTimer: Timer? = nil
    @State private var currentDate: Date = Date()
    @State private var isClockHovered: Bool = false

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
        HStack(spacing: 8) {
            Divider()
                .frame(height: prefs.compactMode ? 22 : 28)

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
        }
        .padding(.trailing, 4)
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
        hoverTimer?.invalidate()
        hoverTimer = nil
        hoveredAppPID = nil
        WindowPreviewWindowController.shared.closePreview()

        // Toggle activation or launch
        AppActionService.shared.toggleActivation(for: app)
    }

    private func handleAppHover(app: RunningApp, hovering: Bool) {
        guard prefs.showWindowPreviews, app.isRunning, !app.windows.isEmpty else {
            WindowPreviewWindowController.shared.closePreview()
            return
        }

        hoverTimer?.invalidate()

        if hovering {
            hoveredAppPID = app.pid
            let mouseX = NSEvent.mouseLocation.x
            // Show preview after a short debounce
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                DispatchQueue.main.async {
                    if self.hoveredAppPID == app.pid, let screen = NSScreen.main ?? NSScreen.screens.first {
                        WindowPreviewWindowController.shared.showPreview(for: app, screenX: mouseX, on: screen)
                    }
                }
            }
        } else {
            // Dismiss after a short delay so the user can move to preview thumbnails
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                DispatchQueue.main.async {
                    if self.hoveredAppPID == app.pid {
                        self.hoveredAppPID = nil
                        WindowPreviewWindowController.shared.closePreview()
                    }
                }
            }
        }
    }
}

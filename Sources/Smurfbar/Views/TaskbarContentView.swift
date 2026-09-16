import SwiftUI

/// The main taskbar content view — a horizontal bar containing all app tiles.
/// Hosted inside the TaskbarPanel via NSHostingView.
struct TaskbarContentView: View {
    @ObservedObject var appMonitor: AppMonitor

    @State private var hoveredAppPID: pid_t? = nil
    @State private var previewApp: RunningApp? = nil
    @State private var hoverTimer: Timer? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main taskbar bar
            HStack(spacing: 2) {
                // Smurfbar logo / menu button (placeholder for Phase 2)
                smurfbarButton

                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, 4)

                // Running apps
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(appMonitor.runningApps) { app in
                            AppTileView(
                                app: app,
                                isActive: app.pid == appMonitor.activeAppPID,
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
            .frame(height: TaskbarPanel.taskbarHeight)

            // Window preview overlay (appears above the taskbar)
            if let previewApp = previewApp, !previewApp.windows.isEmpty {
                WindowPreviewView(app: previewApp) { window in
                    AppActionService.shared.activateWindow(
                        for: previewApp,
                        windowTitle: window.title
                    )
                    self.previewApp = nil
                }
                .offset(y: -(TaskbarPanel.taskbarHeight + 8))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: previewApp?.pid)
    }

    // MARK: - Subviews

    private var smurfbarButton: some View {
        Button(action: {
            // Phase 2: Open app launcher menu
        }) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .help("Smurfbar Menu")
    }

    private var systemArea: some View {
        HStack(spacing: 12) {
            Divider()
                .frame(height: 28)

            // Clock (simple for MVP)
            Text(timeString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
                .help(dateString)
        }
        .padding(.trailing, 4)
    }

    // MARK: - Time Display

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: Date())
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    // MARK: - Interaction Handlers

    private func handleAppTap(_ app: RunningApp) {
        // Dismiss preview
        previewApp = nil
        hoveredAppPID = nil

        // Toggle activation (like Windows taskbar)
        AppActionService.shared.toggleActivation(for: app)
    }

    private func handleAppHover(app: RunningApp, hovering: Bool) {
        hoverTimer?.invalidate()

        if hovering {
            hoveredAppPID = app.pid
            // Show preview after a short delay
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                DispatchQueue.main.async {
                    if self.hoveredAppPID == app.pid {
                        self.previewApp = app
                    }
                }
            }
        } else {
            // Dismiss after a short delay (allows moving mouse to the preview)
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                DispatchQueue.main.async {
                    if self.hoveredAppPID == app.pid {
                        self.hoveredAppPID = nil
                        self.previewApp = nil
                    }
                }
            }
        }
    }
}

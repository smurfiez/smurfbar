import AppKit
import Combine

/// Represents a running application in the taskbar.
class RunningApp: Identifiable, ObservableObject, Equatable {
    let id: String  // bundleIdentifier ?? pid string
    let bundleIdentifier: String?
    let localizedName: String
    let icon: NSImage
    let pid: pid_t
    let nsRunningApp: NSRunningApplication

    @Published var isActive: Bool
    @Published var isHidden: Bool
    @Published var windows: [AppWindow]

    init(from app: NSRunningApplication) {
        self.nsRunningApp = app
        self.pid = app.processIdentifier
        self.bundleIdentifier = app.bundleIdentifier
        self.localizedName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        self.id = app.bundleIdentifier ?? "\(app.processIdentifier)"
        self.isActive = app.isActive
        self.isHidden = app.isHidden
        self.windows = []

        // Get the app icon, fall back to a generic app icon
        if let icon = app.icon {
            icon.size = NSSize(width: 32, height: 32)
            self.icon = icon
        } else {
            self.icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
    }

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.pid == rhs.pid
    }
}

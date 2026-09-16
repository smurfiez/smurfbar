import AppKit
import Combine

/// Represents an application in the taskbar (running, pinned, or both).
class RunningApp: Identifiable, ObservableObject, Equatable {
    let id: String  // bundleIdentifier ?? pid string
    let bundleIdentifier: String?
    let localizedName: String
    let icon: NSImage
    var pid: pid_t?
    var nsRunningApp: NSRunningApplication?

    @Published var isActive: Bool
    @Published var isHidden: Bool
    @Published var isPinned: Bool
    @Published var windows: [AppWindow]

    var isRunning: Bool {
        nsRunningApp != nil && !nsRunningApp!.isTerminated
    }

    var bundleURL: URL? {
        if let url = nsRunningApp?.bundleURL {
            return url
        }
        if let bundleID = bundleIdentifier {
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        }
        return nil
    }

    /// Initialize from an active NSRunningApplication
    init(from app: NSRunningApplication, isPinned: Bool = false) {
        self.nsRunningApp = app
        self.pid = app.processIdentifier
        self.bundleIdentifier = app.bundleIdentifier
        self.localizedName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
        self.id = app.bundleIdentifier ?? "\(app.processIdentifier)"
        self.isActive = app.isActive
        self.isHidden = app.isHidden
        self.isPinned = isPinned
        self.windows = []

        if let icon = app.icon {
            icon.size = NSSize(width: 32, height: 32)
            self.icon = icon
        } else {
            self.icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
    }

    /// Initialize from a PinnedApp that may not currently be running
    init(from pinnedApp: PinnedApp) {
        self.nsRunningApp = nil
        self.pid = nil
        self.bundleIdentifier = pinnedApp.bundleIdentifier
        self.localizedName = pinnedApp.localizedName
        self.id = pinnedApp.bundleIdentifier
        self.isActive = false
        self.isHidden = false
        self.isPinned = true
        self.windows = []

        let appIcon = pinnedApp.icon
        appIcon.size = NSSize(width: 32, height: 32)
        self.icon = appIcon
    }

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        if let lPid = lhs.pid, let rPid = rhs.pid {
            return lPid == rPid
        }
        return lhs.id == rhs.id
    }
}

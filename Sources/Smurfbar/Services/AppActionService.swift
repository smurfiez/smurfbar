import AppKit

/// Handles user-initiated actions on applications (activate, hide, quit, pin, open files, etc.)
class AppActionService {
    static let shared = AppActionService()

    private init() {}

    /// Activate the app (bring all its windows to front).
    /// If the app is already active, hide it instead (toggle behavior).
    /// If the app is not running (pinned), launch it.
    func toggleActivation(for app: RunningApp) {
        guard let nsApp = app.nsRunningApp, app.isRunning else {
            launchApp(app)
            return
        }

        if app.isActive {
            nsApp.hide()
        } else {
            if app.isHidden {
                nsApp.unhide()
            }
            nsApp.activate(options: .activateIgnoringOtherApps)
        }
    }

    /// Activate the app unconditionally, launching it if necessary.
    func activateApp(_ app: RunningApp) {
        guard let nsApp = app.nsRunningApp, app.isRunning else {
            launchApp(app)
            return
        }
        if app.isHidden {
            nsApp.unhide()
        }
        nsApp.activate(options: .activateIgnoringOtherApps)
    }

    /// Launch a non-running app
    func launchApp(_ app: RunningApp) {
        guard let url = app.bundleURL else {
            print("⚠️ Cannot launch \(app.localizedName): bundle URL not found")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                print("❌ Failed to launch \(app.localizedName): \(error.localizedDescription)")
            }
        }
    }

    /// Hide the app.
    func hideApp(_ app: RunningApp) {
        app.nsRunningApp?.hide()
    }

    /// Unhide the app.
    func unhideApp(_ app: RunningApp) {
        app.nsRunningApp?.unhide()
    }

    /// Gracefully quit the app.
    func quitApp(_ app: RunningApp) {
        app.nsRunningApp?.terminate()
    }

    /// Force quit the app.
    func forceQuitApp(_ app: RunningApp) {
        app.nsRunningApp?.forceTerminate()
    }

    /// Pin or unpin the app from the taskbar
    func togglePin(for app: RunningApp) {
        guard let bundleID = app.bundleIdentifier else { return }
        PinnedAppsService.shared.togglePin(
            bundleIdentifier: bundleID,
            localizedName: app.localizedName,
            bundlePath: app.bundleURL?.path
        )
    }

    /// Open files with the application (e.g. for drag-and-drop)
    func openFiles(_ urls: [URL], with app: RunningApp) {
        guard let appURL = app.bundleURL else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config) { _, error in
            if let error = error {
                print("❌ Failed to open files with \(app.localizedName): \(error.localizedDescription)")
            }
        }
    }

    /// Activate a specific window by its title and/or CGWindowID.
    func activateWindow(for app: RunningApp, windowTitle: String, windowID: CGWindowID? = nil) {
        guard let pid = app.pid else {
            activateApp(app)
            return
        }

        let success = AccessibilityService.shared.raiseWindow(
            pid: pid,
            windowTitle: windowTitle,
            windowID: windowID
        )
        if !success {
            activateApp(app)
        }
    }

    /// Show the app's bundle in Finder.
    func showInFinder(_ app: RunningApp) {
        if let url = app.bundleURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    /// Open a new window for the given application (Jump List task)
    func openNewWindow(for app: RunningApp) {
        activateApp(app)
        let script = "tell application \"System Events\" to tell process \"\(app.localizedName)\" to keystroke \"n\" using command down"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }

    /// Open a new private/incognito window for browsers
    func openNewPrivateWindow(for app: RunningApp) {
        activateApp(app)
        let script = "tell application \"System Events\" to tell process \"\(app.localizedName)\" to keystroke \"n\" using {command down, shift down}"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
}

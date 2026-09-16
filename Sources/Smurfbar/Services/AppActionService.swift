import AppKit

/// Handles user-initiated actions on running applications (activate, hide, quit, etc.)
class AppActionService {
    static let shared = AppActionService()

    private init() {}

    /// Activate the app (bring all its windows to front).
    /// If the app is already active, hide it instead (toggle behavior).
    func toggleActivation(for app: RunningApp) {
        if app.isActive {
            app.nsRunningApp.hide()
        } else {
            app.nsRunningApp.activate()
            if app.isHidden {
                app.nsRunningApp.unhide()
            }
        }
    }

    /// Activate the app unconditionally.
    func activateApp(_ app: RunningApp) {
        app.nsRunningApp.unhide()
        app.nsRunningApp.activate()
    }

    /// Hide the app.
    func hideApp(_ app: RunningApp) {
        app.nsRunningApp.hide()
    }

    /// Unhide the app.
    func unhideApp(_ app: RunningApp) {
        app.nsRunningApp.unhide()
    }

    /// Gracefully quit the app.
    func quitApp(_ app: RunningApp) {
        app.nsRunningApp.terminate()
    }

    /// Force quit the app.
    func forceQuitApp(_ app: RunningApp) {
        app.nsRunningApp.forceTerminate()
    }

    /// Activate a specific window by its title.
    func activateWindow(for app: RunningApp, windowTitle: String) {
        let success = AccessibilityService.shared.raiseWindow(
            pid: app.pid,
            windowTitle: windowTitle
        )
        if !success {
            // Fallback: just activate the app
            activateApp(app)
        }
    }

    /// Show the app's bundle in Finder.
    func showInFinder(_ app: RunningApp) {
        if let url = app.nsRunningApp.bundleURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
}

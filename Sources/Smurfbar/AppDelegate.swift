import AppKit

/// The main application delegate that orchestrates all Smurfbar components.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var appMonitor: AppMonitor!
    private var windowController: TaskbarWindowController!
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Check and request Accessibility permissions
        if !AccessibilityService.shared.isAccessibilityGranted() {
            AccessibilityService.shared.requestAccessibilityPermissions()
            // Show a message explaining why permissions are needed
            showAccessibilityAlert()
        }

        // 2. Check and request Screen Recording permissions (needed for live window previews)
        if !ScreenCaptureService.shared.checkPermission() {
            ScreenCaptureService.shared.requestPermission()
        }

        // 2. Initialize the app monitor
        appMonitor = AppMonitor()
        appMonitor.startMonitoring()

        // 3. Create and show the taskbar
        windowController = TaskbarWindowController(appMonitor: appMonitor)
        windowController.showTaskbar()

        // 4. Set up the menu bar status item
        statusBarController = StatusBarController(windowController: windowController)
        statusBarController.setup()

        // 5. Auto-hide the macOS Dock
        DockService.shared.hideDock()

        print("✅ Smurfbar launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop monitoring
        appMonitor?.stopMonitoring()

        // Restore the Dock
        DockService.shared.restoreDock()

        // Clean up status bar
        statusBarController?.teardown()

        print("👋 Smurfbar shutting down")
    }

    /// Prevent the app from terminating when all windows are closed
    /// (since the taskbar panel might be hidden).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Private

    private func showAccessibilityAlert() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Required"
            alert.informativeText = """
            Smurfbar needs Accessibility access to:
            • See which apps and windows are running
            • Show window previews
            • Switch between windows

            Please grant access in System Settings → Privacy & Security → Accessibility, then relaunch Smurfbar.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Continue Anyway")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings → Accessibility
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

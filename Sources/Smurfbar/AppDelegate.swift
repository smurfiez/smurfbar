import AppKit

/// The main application delegate that orchestrates all Smurfbar components.
class AppDelegate: NSObject, NSApplicationDelegate {
    private var appMonitor: AppMonitor!
    private var multiMonitorService: MultiMonitorService!
    private var statusBarController: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Check and request Accessibility permissions
        if !AccessibilityService.shared.isAccessibilityGranted() {
            AccessibilityService.shared.requestAccessibilityPermissions()
        }

        // 2. Check and request Screen Recording permissions (needed for live window previews)
        if !ScreenCaptureService.shared.checkPermission() {
            ScreenCaptureService.shared.requestPermission()
        }

        // 3. Initialize the app monitor
        appMonitor = AppMonitor()
        appMonitor.startMonitoring()

        // 4. Create and manage taskbars across connected displays
        multiMonitorService = MultiMonitorService(appMonitor: appMonitor)
        multiMonitorService.setup()

        // 5. Start Aero Snap edge detection and keyboard shortcuts
        SnapZoneService.shared.start()
        KeyboardShortcutService.shared.start()

        // 6. Set up the menu bar status item
        statusBarController = StatusBarController(multiMonitorService: multiMonitorService)
        statusBarController.setup()

        // 7. Auto-hide the macOS Dock
        DockService.shared.hideDock()

        // 8. Initialize update service (triggers auto-check if enabled)
        _ = UpdateService.shared

        print("✅ Smurfbar launched successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop window snapping services
        SnapZoneService.shared.stop()
        KeyboardShortcutService.shared.stop()

        // Stop multi-monitor taskbars
        multiMonitorService?.teardown()

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


}

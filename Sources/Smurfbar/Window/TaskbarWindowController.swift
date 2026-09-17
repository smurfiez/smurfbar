import AppKit
import SwiftUI

/// Manages the lifecycle of a TaskbarPanel instance for a specific screen.
class TaskbarWindowController {
    private(set) var panel: TaskbarPanel?
    private(set) var isFullScreenSuppressed: Bool = false
    private var appMonitor: AppMonitor
    private var screenObserver: NSObjectProtocol?
    private var assignedScreen: NSScreen?

    var currentScreen: NSScreen? {
        assignedScreen ?? NSScreen.main ?? NSScreen.screens.first
    }

    init(screen: NSScreen? = nil, appMonitor: AppMonitor) {
        self.assignedScreen = screen
        self.appMonitor = appMonitor
    }

    /// Show the taskbar on the assigned screen.
    func showTaskbar() {
        guard let screen = currentScreen else {
            print("⚠️ No screen available")
            return
        }

        // Create the panel
        let taskbarPanel = TaskbarPanel(for: screen)

        // Create the SwiftUI content view with target screen
        let contentView = TaskbarContentView(appMonitor: appMonitor, screen: screen)
        taskbarPanel.setSwiftUIContent(contentView)

        self.panel = taskbarPanel

        // Check if this screen is already in full-screen mode (YouTube / game)
        let isFS = FullScreenService.shared.isFullScreen(on: screen)
        self.isFullScreenSuppressed = isFS
        taskbarPanel.isFullScreenSuppressed = isFS

        if isFS {
            restoreScreenSpace(on: screen)
        } else {
            // Show the panel
            taskbarPanel.orderFrontRegardless()
            // Reserve screen space
            reserveScreenSpace(on: screen)
        }

        // Listen for screen changes
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    /// Hide and destroy the taskbar.
    func hideTaskbar() {
        if let screen = currentScreen {
            restoreScreenSpace(on: screen)
        }
        panel?.orderOut(nil)
        panel = nil
        isFullScreenSuppressed = false

        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
    }

    /// Toggle taskbar visibility.
    func toggleTaskbar() {
        if panel?.isVisible == true {
            hideTaskbar()
        } else {
            showTaskbar()
        }
    }

    /// Suppress (hide) or restore the taskbar when a full-screen window (YouTube/game) is active.
    func setFullScreenSuppressed(_ suppressed: Bool) {
        guard isFullScreenSuppressed != suppressed else { return }
        isFullScreenSuppressed = suppressed
        panel?.isFullScreenSuppressed = suppressed

        guard let screen = currentScreen else { return }

        if suppressed {
            // Dismiss any open flyout windows
            AppLauncherWindowController.shared.closeLauncher()
            CalendarWindowController.shared.closeCalendar()
            QuickSettingsWindowController.shared.closeQuickSettings()
            WeatherWindowController.shared.closeWeather()
            WindowPreviewWindowController.shared.closePreview()

            // Restore full screen space for the app/game
            restoreScreenSpace(on: screen)

            // Hide the panel
            panel?.orderOut(nil)
        } else {
            // Re-reserve taskbar space for standard windows
            reserveScreenSpace(on: screen)

            // Restore panel visibility
            panel?.orderFrontRegardless()
        }
    }

    // MARK: - Screen Management

    func handleScreenChange() {
        guard let screen = currentScreen else { return }
        panel?.reposition(on: screen)
        if isFullScreenSuppressed {
            restoreScreenSpace(on: screen)
        } else {
            reserveScreenSpace(on: screen)
        }
    }

    /// Update target screen if reconfigured
    func updateScreen(_ screen: NSScreen) {
        self.assignedScreen = screen
        handleScreenChange()
    }

    /// Reserve space on the screen so maximized windows don't overlap the taskbar.
    private func reserveScreenSpace(on screen: NSScreen) {
        typealias CGSConnectionID = Int32
        typealias CGSSetWorkspaceRectFunc = @convention(c) (CGSConnectionID, CGRect) -> Int32
        typealias CGSMainConnectionIDFunc = @convention(c) () -> CGSConnectionID

        guard let cgsMainSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSMainConnectionID"),
              let cgsSetRectSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetWorkspaceRect") else {
            return
        }

        let getMainConn = unsafeBitCast(cgsMainSym, to: CGSMainConnectionIDFunc.self)
        let setWorkspaceRect = unsafeBitCast(cgsSetRectSym, to: CGSSetWorkspaceRectFunc.self)
        let cid = getMainConn()

        let thickness = PreferencesService.shared.taskbarThickness
        var rect = screen.frame
        switch PreferencesService.shared.taskbarPosition {
        case .top:
            rect.size.height -= thickness
        case .bottom:
            rect.origin.y += thickness
            rect.size.height -= thickness
        case .left:
            rect.origin.x += thickness
            rect.size.width -= thickness
        case .right:
            rect.size.width -= thickness
        }

        _ = setWorkspaceRect(cid, rect)
    }

    /// Restore the original workspace area on screen
    private func restoreScreenSpace(on screen: NSScreen) {
        typealias CGSConnectionID = Int32
        typealias CGSSetWorkspaceRectFunc = @convention(c) (CGSConnectionID, CGRect) -> Int32
        typealias CGSMainConnectionIDFunc = @convention(c) () -> CGSConnectionID

        guard let cgsMainSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSMainConnectionID"),
              let cgsSetRectSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGSSetWorkspaceRect") else {
            return
        }

        let getMainConn = unsafeBitCast(cgsMainSym, to: CGSMainConnectionIDFunc.self)
        let setWorkspaceRect = unsafeBitCast(cgsSetRectSym, to: CGSSetWorkspaceRectFunc.self)
        let cid = getMainConn()

        _ = setWorkspaceRect(cid, screen.frame)
    }
}

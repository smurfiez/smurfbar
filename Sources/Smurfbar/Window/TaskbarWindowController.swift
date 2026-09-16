import AppKit
import SwiftUI

/// Manages the lifecycle of a TaskbarPanel instance for a specific screen.
class TaskbarWindowController {
    private(set) var panel: TaskbarPanel?
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

        // Show the panel
        taskbarPanel.orderFrontRegardless()
        self.panel = taskbarPanel

        // Reserve screen space
        reserveScreenSpace(on: screen)

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

    // MARK: - Screen Management

    func handleScreenChange() {
        guard let screen = currentScreen else { return }
        panel?.reposition(on: screen)
        reserveScreenSpace(on: screen)
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

        let height = PreferencesService.shared.taskbarHeight
        var rect = screen.frame
        if PreferencesService.shared.taskbarPosition == .top {
            rect.size.height -= height
        } else {
            rect.origin.y += height
            rect.size.height -= height
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

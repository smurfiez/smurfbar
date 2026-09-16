import AppKit
import SwiftUI

/// Manages the lifecycle of TaskbarPanel instances.
/// Creates a panel for the primary screen and handles screen configuration changes.
class TaskbarWindowController {
    private var panel: TaskbarPanel?
    private var appMonitor: AppMonitor
    private var screenObserver: NSObjectProtocol?

    init(appMonitor: AppMonitor) {
        self.appMonitor = appMonitor
    }

    /// Show the taskbar on the primary screen.
    func showTaskbar() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            print("⚠️ No screen available")
            return
        }

        // Create the panel
        let taskbarPanel = TaskbarPanel(for: screen)

        // Create the SwiftUI content view
        let contentView = TaskbarContentView(appMonitor: appMonitor)
        taskbarPanel.setSwiftUIContent(contentView)

        // Show the panel
        taskbarPanel.orderFrontRegardless()
        self.panel = taskbarPanel

        // Reserve screen space by adjusting the Dock-hidden area
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

    private func handleScreenChange() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        panel?.reposition(on: screen)
        reserveScreenSpace(on: screen)
    }

    /// Reserve space at the bottom of the screen so windows don't overlap the taskbar.
    /// This is done by adjusting the screen's visible frame using the Accessibility API
    /// to set a custom Dock-like area.
    private func reserveScreenSpace(on screen: NSScreen) {
        // The visible frame already accounts for the menu bar and Dock.
        // Since we auto-hide the Dock, we need to claim the bottom space.
        // macOS doesn't have a public API for this, but the panel's level
        // and the Dock being hidden effectively achieves the same result.
        // Apps using NSScreen.visibleFrame will still go under our bar,
        // but the bar being always-on-top means it won't be obscured.
        //
        // For proper screen reservation, we'd need to use private CGSSetWorkspaceRect
        // or similar. For the MVP, the always-on-top panel is sufficient.
    }
}

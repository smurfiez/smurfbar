import AppKit
import SwiftUI

/// Window controller managing the Start Menu / App Launcher flyout panel.
class AppLauncherWindowController: NSWindowController {
    static let shared = AppLauncherWindowController()

    private var panel: NSPanel?
    private var localMouseDownMonitor: Any?
    private var globalMouseDownMonitor: Any?

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggle(relativeTo screen: NSScreen, onOpenPreferences: @escaping () -> Void) {
        if isVisible {
            closeLauncher()
        } else {
            showLauncher(on: screen, onOpenPreferences: onOpenPreferences)
        }
    }

    func showLauncher(on screen: NSScreen, onOpenPreferences: @escaping () -> Void) {
        closeLauncher()

        let launcherWidth: CGFloat = 380
        let launcherHeight: CGFloat = 500

        let screenFrame = screen.frame
        let originX = screenFrame.origin.x + 12
        let originY = screenFrame.origin.y + TaskbarPanel.taskbarHeight + 8

        let panelRect = NSRect(x: originX, y: originY, width: launcherWidth, height: launcherHeight)

        let newPanel = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        newPanel.level = .floating
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let flyoutView = AppLauncherFlyoutView(
            onClose: { [weak self] in
                self?.closeLauncher()
            },
            onOpenPreferences: onOpenPreferences
        )

        let hostingView = NSHostingView(rootView: flyoutView)
        hostingView.frame = newPanel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        newPanel.contentView?.addSubview(hostingView)

        newPanel.orderFrontRegardless()
        newPanel.makeKey()
        self.panel = newPanel

        setupEventMonitors()
    }

    func closeLauncher() {
        removeEventMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Outside Click & Key Monitors

    private func setupEventMonitors() {
        removeEventMonitors()

        // Global monitor for clicks outside the launcher
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeLauncher()
        }

        // Local monitor to intercept Escape key
        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.closeLauncher()
                return nil
            }
            return event
        }
    }

    private func removeEventMonitors() {
        if let monitor = globalMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDownMonitor = nil
        }
        if let monitor = localMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseDownMonitor = nil
        }
    }
}

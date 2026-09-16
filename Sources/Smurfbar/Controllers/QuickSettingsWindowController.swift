import AppKit
import SwiftUI

/// Window controller managing the Quick Settings flyout panel.
class QuickSettingsWindowController: NSWindowController {
    static let shared = QuickSettingsWindowController()

    private var panel: NSPanel?
    private var localEventMonitor: Any?
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
            closeQuickSettings()
        } else {
            showQuickSettings(on: screen, onOpenPreferences: onOpenPreferences)
        }
    }

    func showQuickSettings(on screen: NSScreen, onOpenPreferences: @escaping () -> Void) {
        closeQuickSettings()

        let flyoutWidth: CGFloat = 330
        let flyoutHeight: CGFloat = 300

        let screenFrame = screen.frame
        // Position at bottom-right, slightly offset from the edge
        let originX = screenFrame.origin.x + screenFrame.width - flyoutWidth - 12
        let originY = screenFrame.origin.y + TaskbarPanel.taskbarHeight + 8

        let panelRect = NSRect(x: originX, y: originY, width: flyoutWidth, height: flyoutHeight)

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

        let flyoutView = QuickSettingsFlyoutView(
            onClose: { [weak self] in
                self?.closeQuickSettings()
            },
            onOpenPreferences: onOpenPreferences
        )

        let hostingView = NSHostingView(rootView: flyoutView)
        hostingView.frame = newPanel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        newPanel.contentView?.addSubview(hostingView)

        newPanel.orderFrontRegardless()
        self.panel = newPanel

        setupEventMonitors()
    }

    func closeQuickSettings() {
        removeEventMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    private func setupEventMonitors() {
        removeEventMonitors()

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeQuickSettings()
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.closeQuickSettings()
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
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
}

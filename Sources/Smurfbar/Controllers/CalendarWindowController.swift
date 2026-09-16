import AppKit
import SwiftUI

/// Window controller managing the Calendar & Clock flyout panel.
class CalendarWindowController: NSWindowController {
    static let shared = CalendarWindowController()

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

    func toggle(relativeTo screen: NSScreen) {
        if isVisible {
            closeCalendar()
        } else {
            showCalendar(on: screen)
        }
    }

    func showCalendar(on screen: NSScreen) {
        closeCalendar()

        let flyoutWidth: CGFloat = 320
        let flyoutHeight: CGFloat = 360

        let screenFrame = screen.frame
        // Position at bottom-right of the screen, just above the taskbar
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

        let flyoutView = CalendarFlyoutView(
            onClose: { [weak self] in
                self?.closeCalendar()
            }
        )

        let hostingView = NSHostingView(rootView: flyoutView)
        hostingView.frame = newPanel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        newPanel.contentView?.addSubview(hostingView)

        newPanel.orderFrontRegardless()
        self.panel = newPanel

        setupEventMonitors()
    }

    func closeCalendar() {
        removeEventMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    private func setupEventMonitors() {
        removeEventMonitors()

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeCalendar()
        }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.closeCalendar()
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

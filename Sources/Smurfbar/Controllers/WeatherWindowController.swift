import AppKit
import SwiftUI

/// Window controller managing the Windows 11 style Weather & Forecast flyout panel.
public class WeatherWindowController: NSWindowController {
    public static let shared = WeatherWindowController()

    private var panel: NSPanel?
    private var globalMouseDownMonitor: Any?
    private var localEventMonitor: Any?

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var isVisible: Bool {
        panel?.isVisible == true
    }

    public func toggle(relativeTo screen: NSScreen, anchorX: CGFloat? = nil) {
        if isVisible {
            closeWeather()
        } else {
            showWeather(on: screen, anchorX: anchorX)
        }
    }

    public func showWeather(on screen: NSScreen, anchorX: CGFloat? = nil) {
        closeWeather()

        let flyoutWidth: CGFloat = 360
        let flyoutHeight: CGFloat = 480
        let screenFrame = screen.frame
        let prefs = PreferencesService.shared

        var originX: CGFloat
        var originY: CGFloat

        switch prefs.taskbarPosition {
        case .bottom:
            originY = screenFrame.origin.y + prefs.taskbarHeight + 8
            if let anchor = anchorX {
                originX = max(screenFrame.origin.x + 8, min(anchor - (flyoutWidth / 2), screenFrame.origin.x + screenFrame.width - flyoutWidth - 8))
            } else {
                originX = screenFrame.origin.x + 12
            }
        case .top:
            originY = screenFrame.origin.y + screenFrame.height - prefs.taskbarHeight - flyoutHeight - 8
            if let anchor = anchorX {
                originX = max(screenFrame.origin.x + 8, min(anchor - (flyoutWidth / 2), screenFrame.origin.x + screenFrame.width - flyoutWidth - 8))
            } else {
                originX = screenFrame.origin.x + 12
            }
        case .left:
            originX = screenFrame.origin.x + prefs.taskbarThickness + 8
            originY = screenFrame.origin.y + 12
        case .right:
            originX = screenFrame.origin.x + screenFrame.width - prefs.taskbarThickness - flyoutWidth - 8
            originY = screenFrame.origin.y + 12
        }

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

        let flyoutView = WeatherFlyoutView(
            onClose: { [weak self] in
                self?.closeWeather()
            }
        )

        let hostingView = FirstMouseHostingView(rootView: flyoutView)
        hostingView.frame = newPanel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        newPanel.contentView?.addSubview(hostingView)

        newPanel.orderFrontRegardless()
        self.panel = newPanel

        setupEventMonitors()
    }

    public func closeWeather() {
        removeEventMonitors()
        panel?.orderOut(nil)
        panel = nil
    }

    private func setupEventMonitors() {
        removeEventMonitors()

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeWeather()
        }

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.closeWeather()
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

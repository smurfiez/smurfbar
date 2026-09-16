import AppKit
import SwiftUI

/// Window controller that manages the floating window thumbnail preview popover.
class WindowPreviewWindowController: NSWindowController {
    static let shared = WindowPreviewWindowController()

    private var panel: NSPanel?
    private var currentPID: pid_t?

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    /// Show the preview panel for the specified app positioned above its tile.
    func showPreview(for app: RunningApp, screenX: CGFloat, on screen: NSScreen) {
        guard PreferencesService.shared.showWindowPreviews else { return }
        guard !app.windows.isEmpty else {
            closePreview()
            return
        }

        currentPID = app.pid

        let windowCount = app.windows.count
        let itemWidth: CGFloat = 170
        let padding: CGFloat = 24
        let estimatedWidth = min(max(CGFloat(windowCount) * itemWidth + padding, 220), 540)
        let panelHeight: CGFloat = 165

        let screenFrame = screen.frame
        let targetX = screenX - (estimatedWidth / 2)
        let clampedX = max(screenFrame.origin.x + 12, min(targetX, screenFrame.origin.x + screenFrame.width - estimatedWidth - 12))
        let originY = screenFrame.origin.y + PreferencesService.shared.taskbarHeight + 8

        let panelRect = NSRect(x: clampedX, y: originY, width: estimatedWidth, height: panelHeight)

        if let existingPanel = panel {
            existingPanel.setFrame(panelRect, display: true, animate: false)
            updateContent(for: app, in: existingPanel)
            if !existingPanel.isVisible {
                existingPanel.orderFrontRegardless()
            }
            return
        }

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

        updateContent(for: app, in: newPanel)

        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }

    private func updateContent(for app: RunningApp, in panel: NSPanel) {
        let previewView = WindowPreviewView(app: app) { [weak self] window in
            AppActionService.shared.activateWindow(for: app, windowTitle: window.title)
            self?.closePreview()
        }

        let hostingView = NSHostingView(rootView: previewView)
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    /// Close and dismiss the preview panel.
    func closePreview() {
        currentPID = nil
        panel?.orderOut(nil)
        panel = nil
    }

    func isShowing(for pid: pid_t?) -> Bool {
        guard let pid = pid, let current = currentPID else { return false }
        return isVisible && current == pid
    }
}

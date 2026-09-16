import AppKit
import SwiftUI


/// Window controller that manages the floating window thumbnail preview popover.
class WindowPreviewWindowController: NSWindowController {
    static let shared = WindowPreviewWindowController()

    private var panel: NSPanel?
    private var currentPID: pid_t?

    private var isMouseOverTile: Bool = false
    private var isMouseOverPreview: Bool = false
    private var dismissTimer: Timer?
    private var showTimer: Timer?

    private init() {
        super.init(window: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    /// Called by the taskbar when the mouse enters or exits an app tile.
    func handleTileHover(app: RunningApp, screenX: CGFloat, on screen: NSScreen, isHovering: Bool) {
        guard PreferencesService.shared.showWindowPreviews else {
            closePreview()
            return
        }

        if isHovering {
            isMouseOverTile = true
            cancelDismissTimer()

            // If a preview is ALREADY visible for another app, switch almost immediately!
            if isVisible && currentPID != app.pid {
                showTimer?.invalidate()
                showTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
                    self?.showPreview(for: app, screenX: screenX, on: screen)
                }
            } else if !isVisible {
                // Debounce initial display
                showTimer?.invalidate()
                showTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                    self?.showPreview(for: app, screenX: screenX, on: screen)
                }
            }
        } else {
            isMouseOverTile = false
            showTimer?.invalidate()
            showTimer = nil
            checkDismissal()
        }
    }

    /// Called when the mouse enters or leaves the preview popover itself.
    func setMouseOverPreview(_ isOver: Bool) {
        isMouseOverPreview = isOver
        if isOver {
            cancelDismissTimer()
        } else {
            checkDismissal()
        }
    }

    private func checkDismissal() {
        // If the mouse is neither over the tile nor over the preview popover, schedule dismissal
        guard !isMouseOverTile && !isMouseOverPreview else { return }

        cancelDismissTimer()
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if !self.isMouseOverTile && !self.isMouseOverPreview {
                    self.closePreview()
                }
            }
        }
    }

    private func cancelDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = nil
    }

    /// Show the preview panel for the specified app positioned above its tile.
    func showPreview(for app: RunningApp, screenX: CGFloat, on screen: NSScreen) {
        guard PreferencesService.shared.showWindowPreviews else { return }
        guard app.isRunning, !app.windows.isEmpty else {
            closePreview()
            return
        }

        currentPID = app.pid

        let windowCount = max(app.windows.count, 1)
        let itemWidth: CGFloat = 175
        let padding: CGFloat = 24
        let estimatedWidth = min(max(CGFloat(windowCount) * itemWidth + padding, 220), 560)
        let panelHeight: CGFloat = 165

        // Determine correct screen based on mouse cursor or passed screen
        let activeScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? screen
        let screenFrame = activeScreen.frame
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

        // Ensure preview floats above the taskbar (.statusBar is 25, popUpMenu is 101)
        newPanel.level = .popUpMenu
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = false
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.acceptsMouseMovedEvents = true
        newPanel.ignoresMouseEvents = false
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        updateContent(for: app, in: newPanel)

        newPanel.orderFrontRegardless()
        self.panel = newPanel
    }

    private func updateContent(for app: RunningApp, in panel: NSPanel) {
        let previewView = WindowPreviewView(app: app) { [weak self] window in
            AppActionService.shared.activateWindow(for: app, windowTitle: window.title, windowID: window.windowID)
            self?.closePreview()
        }

        let hostingView = FirstMouseHostingView(rootView: previewView)
        hostingView.frame = panel.contentView?.bounds ?? panel.frame
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
    }

    /// Close and dismiss the preview panel immediately.
    func closePreview() {
        showTimer?.invalidate()
        showTimer = nil
        dismissTimer?.invalidate()
        dismissTimer = nil
        isMouseOverTile = false
        isMouseOverPreview = false
        currentPID = nil

        panel?.orderOut(nil)
        panel = nil
    }

    func isShowing(for pid: pid_t?) -> Bool {
        guard let pid = pid, let current = currentPID else { return false }
        return isVisible && current == pid
    }
}

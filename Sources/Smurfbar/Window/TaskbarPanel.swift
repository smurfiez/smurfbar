import AppKit
import SwiftUI
import Combine

/// A custom NSPanel subclass that acts as the taskbar.
/// Non-activating (doesn't steal focus), always on top, anchored to the bottom of the screen.
class TaskbarPanel: NSPanel {
    static var taskbarHeight: CGFloat {
        PreferencesService.shared.taskbarHeight
    }

    private var visualEffectView: NSVisualEffectView?
    private var topBorder: NSBox?
    private var cancellables = Set<AnyCancellable>()
    private var autoHideTimer: Timer?
    private var mouseMonitor: Any?
    private(set) var isPanelHidden: Bool = false
    private weak var targetScreen: NSScreen?

    init(for screen: NSScreen) {
        self.targetScreen = screen
        let pos = PreferencesService.shared.taskbarPosition
        let panelFrame = Self.computeFrame(for: screen, position: pos, isHidden: false)

        super.init(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        setupObservers()
    }

    private func configurePanel() {
        // Window level: above normal windows but below alerts/menus
        self.level = .statusBar

        // Non-activating: clicking the taskbar won't steal focus
        self.isFloatingPanel = true

        // Appearance
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.alphaValue = CGFloat(PreferencesService.shared.taskbarOpacity)

        // Behavior
        self.collectionBehavior = [
            .canJoinAllSpaces,     // Show on all Spaces/Desktops
            .stationary,           // Don't move with spaces
            .fullScreenAuxiliary,  // Show alongside fullscreen apps
            .ignoresCycle          // Don't appear in Cmd+Tab / window cycling
        ]

        // Don't show in Mission Control
        self.isExcludedFromWindowsMenu = true

        // Can receive mouse events but not become key window
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false

        // Add vibrancy background
        let visualEffect = NSVisualEffectView(frame: self.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = PreferencesService.shared.theme.visualEffectMaterial
        visualEffect.state = .active
        self.visualEffectView = visualEffect

        // Add border separator
        let border = NSBox(frame: .zero)
        border.boxType = .separator
        self.topBorder = border

        self.contentView?.addSubview(visualEffect, positioned: .below, relativeTo: nil)
        self.contentView?.addSubview(border)
        updateBorderPosition()
    }

    private func setupObservers() {
        let prefs = PreferencesService.shared

        // Theme observer
        prefs.$theme
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme in
                self?.appearance = theme.appearance
                self?.visualEffectView?.material = theme.visualEffectMaterial
            }
            .store(in: &cancellables)

        self.appearance = prefs.theme.appearance

        // Compact mode / height observer
        prefs.$compactMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let screen = self.targetScreen else { return }
                self.reposition(on: screen)
            }
            .store(in: &cancellables)

        // Taskbar Position observer
        prefs.$taskbarPosition
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, let screen = self.targetScreen else { return }
                self.reposition(on: screen)
                self.updateBorderPosition()
            }
            .store(in: &cancellables)

        // Taskbar Opacity observer
        prefs.$taskbarOpacity
            .receive(on: DispatchQueue.main)
            .sink { [weak self] opacity in
                self?.alphaValue = CGFloat(opacity)
            }
            .store(in: &cancellables)

        // Auto-hide observer
        prefs.$autoHide
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.configureAutoHide(enabled: enabled)
            }
            .store(in: &cancellables)

        configureAutoHide(enabled: prefs.autoHide)
    }

    private func updateBorderPosition() {
        guard let border = topBorder, let content = contentView else { return }
        let pos = PreferencesService.shared.taskbarPosition

        switch pos {
        case .bottom:
            border.frame = NSRect(x: 0, y: content.bounds.height - 0.5, width: content.bounds.width, height: 0.5)
            border.autoresizingMask = [.width, .minYMargin]
        case .top:
            border.frame = NSRect(x: 0, y: 0, width: content.bounds.width, height: 0.5)
            border.autoresizingMask = [.width, .maxYMargin]
        case .left:
            border.frame = NSRect(x: content.bounds.width - 0.5, y: 0, width: 0.5, height: content.bounds.height)
            border.autoresizingMask = [.height, .minXMargin]
        case .right:
            border.frame = NSRect(x: 0, y: 0, width: 0.5, height: content.bounds.height)
            border.autoresizingMask = [.height, .maxXMargin]
        }
    }

    // MARK: - Auto-Hide Management

    private func configureAutoHide(enabled: Bool) {
        if enabled {
            startAutoHideMonitoring()
        } else {
            stopAutoHideMonitoring()
            revealPanel(animated: true)
        }
    }

    private func startAutoHideMonitoring() {
        stopAutoHideMonitoring()

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.handleGlobalMouseMove()
        }
    }

    private func stopAutoHideMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    private func handleGlobalMouseMove() {
        guard PreferencesService.shared.autoHide, let screen = targetScreen else { return }
        let mouseLocation = NSEvent.mouseLocation
        let pos = PreferencesService.shared.taskbarPosition

        let isAtTrigger = isMouseAtTriggerEdge(mouse: mouseLocation, screen: screen, position: pos)
        let isInsidePanel = self.frame.contains(mouseLocation)

        if isAtTrigger || isInsidePanel {
            autoHideTimer?.invalidate()
            autoHideTimer = nil
            if isPanelHidden {
                revealPanel(animated: true)
            }
        } else if !isPanelHidden && autoHideTimer == nil {
            // Mouse is away, schedule slide hide
            autoHideTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                self?.hidePanel(animated: true)
            }
        }
    }

    private func isMouseAtTriggerEdge(mouse: CGPoint, screen: NSScreen, position: TaskbarPosition) -> Bool {
        let frame = screen.frame
        switch position {
        case .bottom:
            return mouse.x >= frame.minX && mouse.x <= frame.maxX && mouse.y <= frame.minY + 4
        case .top:
            return mouse.x >= frame.minX && mouse.x <= frame.maxX && mouse.y >= frame.maxY - 4
        case .left:
            return mouse.y >= frame.minY && mouse.y <= frame.maxY && mouse.x <= frame.minX + 4
        case .right:
            return mouse.y >= frame.minY && mouse.y <= frame.maxY && mouse.x >= frame.maxX - 4
        }
    }

    private func revealPanel(animated: Bool) {
        guard let screen = targetScreen else { return }
        isPanelHidden = false
        let pos = PreferencesService.shared.taskbarPosition
        let activeFrame = Self.computeFrame(for: screen, position: pos, isHidden: false)
        self.setFrame(activeFrame, display: true, animate: animated)
    }

    private func hidePanel(animated: Bool) {
        guard let screen = targetScreen else { return }
        isPanelHidden = true
        let pos = PreferencesService.shared.taskbarPosition
        let hiddenFrame = Self.computeFrame(for: screen, position: pos, isHidden: true)
        self.setFrame(hiddenFrame, display: true, animate: animated)
    }

    /// Reposition the panel to the given screen and configured edge.
    func reposition(on screen: NSScreen) {
        self.targetScreen = screen
        let pos = PreferencesService.shared.taskbarPosition
        let newFrame = Self.computeFrame(for: screen, position: pos, isHidden: false)
        self.setFrame(newFrame, display: true, animate: false)
    }

    private static func computeFrame(for screen: NSScreen, position: TaskbarPosition, isHidden: Bool = false) -> NSRect {
        let screenFrame = screen.frame
        let thickness = PreferencesService.shared.taskbarThickness

        switch position {
        case .bottom:
            let y = isHidden ? (screenFrame.origin.y - thickness + 2) : screenFrame.origin.y
            return NSRect(x: screenFrame.origin.x, y: y, width: screenFrame.width, height: thickness)

        case .top:
            let y = isHidden ? (screenFrame.origin.y + screenFrame.height - 2) : (screenFrame.origin.y + screenFrame.height - thickness)
            return NSRect(x: screenFrame.origin.x, y: y, width: screenFrame.width, height: thickness)

        case .left:
            let x = isHidden ? (screenFrame.origin.x - thickness + 2) : screenFrame.origin.x
            return NSRect(x: x, y: screenFrame.origin.y, width: thickness, height: screenFrame.height)

        case .right:
            let x = isHidden ? (screenFrame.origin.x + screenFrame.width - 2) : (screenFrame.origin.x + screenFrame.width - thickness)
            return NSRect(x: x, y: screenFrame.origin.y, width: thickness, height: screenFrame.height)
        }
    }

    /// Host a SwiftUI view inside this panel.
    func setSwiftUIContent<Content: View>(_ content: Content) {
        let hostingView = FirstMouseHostingView(rootView: content)
        hostingView.frame = self.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]

        // Insert the hosting view above the visual effect view but below the border
        self.contentView?.addSubview(hostingView, positioned: .above,
                                     relativeTo: self.contentView?.subviews.first)
    }

    deinit {
        stopAutoHideMonitoring()
    }

    // MARK: - Override to prevent becoming key/main window

    override var canBecomeKey: Bool { true }  // Need key for mouse events
    override var canBecomeMain: Bool { false }
}

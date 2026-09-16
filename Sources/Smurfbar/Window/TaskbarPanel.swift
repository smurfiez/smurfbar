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
        let screenFrame = screen.frame
        let height = PreferencesService.shared.taskbarHeight
        let panelFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: height
        )

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

        // Add a subtle top border
        let border = NSBox(frame: NSRect(x: 0, y: self.contentView!.bounds.height - 0.5,
                                         width: self.contentView!.bounds.width, height: 0.5))
        border.boxType = .separator
        border.autoresizingMask = [.width, .minYMargin]
        self.topBorder = border

        self.contentView?.addSubview(visualEffect, positioned: .below, relativeTo: nil)
        self.contentView?.addSubview(border)
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

        // Auto-hide observer
        prefs.$autoHide
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                self?.configureAutoHide(enabled: enabled)
            }
            .store(in: &cancellables)

        configureAutoHide(enabled: prefs.autoHide)
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
        let screenFrame = screen.frame

        // Check if mouse is near bottom edge (within 4 points of bottom)
        let isAtBottomEdge = (mouseLocation.x >= screenFrame.origin.x &&
                              mouseLocation.x <= screenFrame.origin.x + screenFrame.width &&
                              mouseLocation.y <= screenFrame.origin.y + 4)

        // Check if mouse is inside the taskbar frame
        let isInsidePanel = self.frame.contains(mouseLocation)

        if isAtBottomEdge || isInsidePanel {
            autoHideTimer?.invalidate()
            autoHideTimer = nil
            if isPanelHidden {
                revealPanel(animated: true)
            }
        } else if !isPanelHidden && autoHideTimer == nil {
            // Mouse is away, schedule slide down
            autoHideTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in
                self?.hidePanel(animated: true)
            }
        }
    }

    private func revealPanel(animated: Bool) {
        guard let screen = targetScreen else { return }
        isPanelHidden = false
        let height = PreferencesService.shared.taskbarHeight
        let activeFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: height
        )
        self.setFrame(activeFrame, display: true, animate: animated)
    }

    private func hidePanel(animated: Bool) {
        guard let screen = targetScreen else { return }
        isPanelHidden = true
        let height = PreferencesService.shared.taskbarHeight
        // Slide down leaving a 2px trigger strip
        let hiddenFrame = NSRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y - height + 2,
            width: screen.frame.width,
            height: height
        )
        self.setFrame(hiddenFrame, display: true, animate: animated)
    }

    /// Reposition the panel to the bottom of the given screen.
    func reposition(on screen: NSScreen) {
        self.targetScreen = screen
        let screenFrame = screen.frame
        let height = PreferencesService.shared.taskbarHeight
        let newFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: height
        )
        self.setFrame(newFrame, display: true, animate: false)
    }

    /// Host a SwiftUI view inside this panel.
    func setSwiftUIContent<Content: View>(_ content: Content) {
        let hostingView = NSHostingView(rootView: content)
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

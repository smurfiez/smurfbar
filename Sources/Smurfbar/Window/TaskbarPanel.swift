import AppKit
import SwiftUI

/// A custom NSPanel subclass that acts as the taskbar.
/// Non-activating (doesn't steal focus), always on top, anchored to the bottom of the screen.
class TaskbarPanel: NSPanel {
    static let taskbarHeight: CGFloat = 48

    init(for screen: NSScreen) {
        let screenFrame = screen.frame
        let panelFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: Self.taskbarHeight
        )

        super.init(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        configurePanel()
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
        visualEffect.material = .menu
        visualEffect.state = .active

        // Add a subtle top border
        let border = NSBox(frame: NSRect(x: 0, y: self.contentView!.bounds.height - 0.5,
                                         width: self.contentView!.bounds.width, height: 0.5))
        border.boxType = .separator
        border.autoresizingMask = [.width, .minYMargin]

        self.contentView?.addSubview(visualEffect, positioned: .below, relativeTo: nil)
        self.contentView?.addSubview(border)
    }

    /// Reposition the panel to the bottom of the given screen.
    func reposition(on screen: NSScreen) {
        let screenFrame = screen.frame
        let newFrame = NSRect(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: Self.taskbarHeight
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

    // MARK: - Override to prevent becoming key/main window

    override var canBecomeKey: Bool { true }  // Need key for mouse events
    override var canBecomeMain: Bool { false }
}

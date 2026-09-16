import AppKit
import Combine

/// Manages Aero Snap edge drag detection and window tiling.
class SnapZoneService {
    static let shared = SnapZoneService()

    private var mouseMonitor: Any?
    private var currentTargetFrame: CGRect?
    private var isDragging: Bool = false

    private init() {}

    func start() {
        stop()

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDragged, .leftMouseUp]
        ) { [weak self] event in
            self?.handleMouseEvent(event)
        }
    }

    func stop() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        SnapOverlayWindow.shared.hide()
        SnapLayoutsBarWindow.shared.hide()
        currentTargetFrame = nil
        isDragging = false
    }

    private func handleMouseEvent(_ event: NSEvent) {
        guard PreferencesService.shared.enableWindowSnapping else {
            if currentTargetFrame != nil {
                SnapOverlayWindow.shared.hide()
                SnapLayoutsBarWindow.shared.hide()
                currentTargetFrame = nil
            }
            return
        }

        if event.type == .leftMouseDragged {
            isDragging = true
            let mouse = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) else { return }
            let usable = usableScreenFrame(on: screen)

            // 1. Windows 11 Snap Layouts Drop Bar Check
            if PreferencesService.shared.enableSnapLayoutsBar {
                let screenFrame = screen.frame
                let cornerThreshold: CGFloat = 80.0
                let isTopZone = mouse.y >= screenFrame.maxY - 60 &&
                                mouse.x > screenFrame.minX + cornerThreshold &&
                                mouse.x < screenFrame.maxX - cornerThreshold
                let isInsideBar = SnapLayoutsBarWindow.shared.isVisibleOnScreen &&
                                  SnapLayoutsBarWindow.shared.frame.insetBy(dx: -15, dy: -20).contains(mouse)

                if isTopZone || isInsideBar {
                    if !SnapLayoutsBarWindow.shared.isVisibleOnScreen {
                        SnapLayoutsBarWindow.shared.show(on: screen)
                    }

                    if let (_, target) = SnapLayoutsBarWindow.shared.hitTestZone(at: mouse, on: screen, usable: usable) {
                        currentTargetFrame = target
                        SnapOverlayWindow.shared.show(in: target)
                        return
                    } else if SnapLayoutsBarWindow.shared.frame.contains(mouse) {
                        // Inside the bar header/margins, clear overlay until hovered over a zone
                        SnapOverlayWindow.shared.hide()
                        currentTargetFrame = nil
                        return
                    }
                } else if mouse.y < screenFrame.maxY - 130 {
                    // Dragged away from the top area
                    SnapLayoutsBarWindow.shared.hide()
                }
            }

            // 2. Fallback to classic Aero Snap edges & corners
            if let target = evaluateSnapZone(mouse: mouse, on: screen) {
                currentTargetFrame = target
                SnapOverlayWindow.shared.show(in: target)
            } else {
                if currentTargetFrame != nil {
                    SnapOverlayWindow.shared.hide()
                    currentTargetFrame = nil
                }
            }
        } else if event.type == .leftMouseUp {
            if isDragging, let target = currentTargetFrame {
                // Apply snap to the frontmost application window
                if let window = AccessibilityService.shared.getFrontmostWindow() {
                    _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: target)
                }
            }
            SnapOverlayWindow.shared.hide()
            SnapLayoutsBarWindow.shared.hide()
            currentTargetFrame = nil
            isDragging = false
        }
    }

    /// Calculate target snap frame based on screen and cursor proximity to screen edges
    func evaluateSnapZone(mouse: CGPoint, on screen: NSScreen) -> CGRect? {
        let frame = screen.frame
        let threshold: CGFloat = 12.0
        let cornerThreshold: CGFloat = 80.0

        let usable = usableScreenFrame(on: screen)

        let isTop = mouse.y >= frame.maxY - threshold
        let isBottom = mouse.y <= frame.minY + threshold
        let isLeft = mouse.x <= frame.minX + threshold
        let isRight = mouse.x >= frame.maxX - threshold

        // Corners: Quarter screen snap
        if isTop && mouse.x <= frame.minX + cornerThreshold {
            return CGRect(x: usable.minX, y: usable.minY + usable.height / 2, width: usable.width / 2, height: usable.height / 2)
        }
        if isTop && mouse.x >= frame.maxX - cornerThreshold {
            return CGRect(x: usable.minX + usable.width / 2, y: usable.minY + usable.height / 2, width: usable.width / 2, height: usable.height / 2)
        }
        if isBottom && mouse.x <= frame.minX + cornerThreshold {
            return CGRect(x: usable.minX, y: usable.minY, width: usable.width / 2, height: usable.height / 2)
        }
        if isBottom && mouse.x >= frame.maxX - cornerThreshold {
            return CGRect(x: usable.minX + usable.width / 2, y: usable.minY, width: usable.width / 2, height: usable.height / 2)
        }

        // Edges: Maximize, Left Half, Right Half
        if isTop {
            return usable
        }
        if isLeft {
            return CGRect(x: usable.minX, y: usable.minY, width: usable.width / 2, height: usable.height)
        }
        if isRight {
            return CGRect(x: usable.minX + usable.width / 2, y: usable.minY, width: usable.width / 2, height: usable.height)
        }

        return nil
    }

    /// Calculate the available workspace area on a screen accounting for Taskbar and Menu Bar
    func usableScreenFrame(on screen: NSScreen) -> CGRect {
        var usable = screen.visibleFrame
        let height = PreferencesService.shared.taskbarHeight
        let pos = PreferencesService.shared.taskbarPosition

        if pos == .top {
            usable.size.height -= height
        } else {
            usable.origin.y += height
            usable.size.height -= height
        }

        return usable
    }
}

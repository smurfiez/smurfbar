import AppKit

/// Manages global keyboard shortcuts for window management and Aero Snap.
class KeyboardShortcutService {
    static let shared = KeyboardShortcutService()

    private var keyMonitor: Any?
    private var preSnapFrames: [pid_t: CGRect] = [:]

    private init() {}

    func start() {
        stop()

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
    }

    func stop() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard PreferencesService.shared.enableWindowSnapping else { return }

        // Must have Control key pressed
        guard event.modifierFlags.contains(.control) else { return }

        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let window = AccessibilityService.shared.getFrontmostWindow() else {
            return
        }

        let pid = frontApp.processIdentifier
        let currentWindowFrame = AccessibilityService.shared.getWindowFrame(window: window)

        // Find which screen contains the window
        let centerPoint = currentWindowFrame.map { CGPoint(x: $0.midX, y: $0.midY) } ?? NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(centerPoint) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let usable = SnapZoneService.shared.usableScreenFrame(on: screen)

        // Check for multi-monitor move: Control + Option + Left / Right
        if event.modifierFlags.contains(.option) {
            if event.keyCode == 123 || event.keyCode == 124 { // Left or Right arrow
                moveWindowToAdjacentScreen(window: window, currentScreen: screen, forward: event.keyCode == 124)
                return
            }
        }

        switch event.keyCode {
        case 126: // Up Arrow -> Maximize
            savePreSnapFrame(pid: pid, frame: currentWindowFrame)
            _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: usable)

        case 123: // Left Arrow -> Left Half
            savePreSnapFrame(pid: pid, frame: currentWindowFrame)
            let leftHalf = CGRect(x: usable.minX, y: usable.minY, width: usable.width / 2, height: usable.height)
            _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: leftHalf)

        case 124: // Right Arrow -> Right Half
            savePreSnapFrame(pid: pid, frame: currentWindowFrame)
            let rightHalf = CGRect(x: usable.minX + usable.width / 2, y: usable.minY, width: usable.width / 2, height: usable.height)
            _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: rightHalf)

        case 125: // Down Arrow -> Restore
            if let saved = preSnapFrames.removeValue(forKey: pid) {
                _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: saved)
            } else {
                // Default restore: center 70% of usable area
                let w = usable.width * 0.7
                let h = usable.height * 0.7
                let restored = CGRect(x: usable.minX + (usable.width - w) / 2,
                                      y: usable.minY + (usable.height - h) / 2,
                                      width: w, height: h)
                _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: restored)
            }

        default:
            break
        }
    }

    private func savePreSnapFrame(pid: pid_t, frame: CGRect?) {
        guard let frame = frame, preSnapFrames[pid] == nil else { return }
        preSnapFrames[pid] = frame
    }

    private func moveWindowToAdjacentScreen(window: AXUIElement, currentScreen: NSScreen, forward: Bool) {
        let screens = NSScreen.screens
        guard screens.count > 1,
              let currentIndex = screens.firstIndex(where: { $0.frame == currentScreen.frame }) else { return }

        let targetIndex: Int
        if forward {
            targetIndex = (currentIndex + 1) % screens.count
        } else {
            targetIndex = (currentIndex - 1 + screens.count) % screens.count
        }

        let targetScreen = screens[targetIndex]
        let currentUsable = SnapZoneService.shared.usableScreenFrame(on: currentScreen)
        let targetUsable = SnapZoneService.shared.usableScreenFrame(on: targetScreen)

        guard let currentFrame = AccessibilityService.shared.getWindowFrame(window: window) else { return }

        // Compute relative position and scale on target display
        let relX = (currentFrame.minX - currentUsable.minX) / currentUsable.width
        let relY = (currentFrame.minY - currentUsable.minY) / currentUsable.height
        let relW = currentFrame.width / currentUsable.width
        let relH = currentFrame.height / currentUsable.height

        let newFrame = CGRect(
            x: targetUsable.minX + relX * targetUsable.width,
            y: targetUsable.minY + relY * targetUsable.height,
            width: min(targetUsable.width, relW * targetUsable.width),
            height: min(targetUsable.height, relH * targetUsable.height)
        )

        _ = AccessibilityService.shared.setWindowFrame(window: window, cocoaFrame: newFrame)
    }
}

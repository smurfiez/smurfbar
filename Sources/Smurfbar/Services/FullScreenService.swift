import AppKit
import ApplicationServices
import Combine

/// Service that detects when a full screen video (e.g. YouTube in any browser)
/// or a game app is active in full screen mode, so Smurfbar can hide itself.
class FullScreenService: ObservableObject {
    static let shared = FullScreenService()

    @Published private(set) var fullScreenDisplayIDs: Set<CGDirectDisplayID> = []

    var onFullScreenStateChanged: ((CGDirectDisplayID, Bool) -> Void)?

    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var isRunning: Bool = false

    private init() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let ws = NSWorkspace.shared
        let nc = ws.notificationCenter

        // Listen for active space changes (native fullscreen spaces switch)
        observers.append(
            nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.checkFullScreenState()
            }
        )

        // Listen for app activation / deactivation
        observers.append(
            nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.checkFullScreenState()
            }
        )
        observers.append(
            nc.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.checkFullScreenState()
            }
        )

        // Listen for display configuration changes
        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.checkFullScreenState()
            }
        )

        // Observe preference changes
        PreferencesService.shared.$hideOnFullScreen
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkFullScreenState()
            }
            .store(in: &cancellables)

        // Periodic timer: Lightweight (~0.2ms) poll to immediately catch
        // in-page video fullscreen switches (e.g. pressing 'f' on YouTube)
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.checkFullScreenState()
        }

        // Initial check
        checkFullScreenState()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
        cancellables.removeAll()

        timer?.invalidate()
        timer = nil

        fullScreenDisplayIDs.removeAll()
    }

    /// Check full screen status across all screens and notify when state changes
    func checkFullScreenState() {
        guard PreferencesService.shared.hideOnFullScreen else {
            if !fullScreenDisplayIDs.isEmpty {
                let previous = fullScreenDisplayIDs
                fullScreenDisplayIDs.removeAll()
                for did in previous {
                    onFullScreenStateChanged?(did, false)
                }
            }
            return
        }

        var newFullScreenIDs = Set<CGDirectDisplayID>()

        for screen in NSScreen.screens {
            guard let did = displayID(for: screen) else { continue }
            if isFullScreen(on: screen) {
                newFullScreenIDs.insert(did)
            }
        }

        // Detect additions and removals
        let entered = newFullScreenIDs.subtracting(fullScreenDisplayIDs)
        let exited = fullScreenDisplayIDs.subtracting(newFullScreenIDs)

        fullScreenDisplayIDs = newFullScreenIDs

        for did in entered {
            onFullScreenStateChanged?(did, true)
        }
        for did in exited {
            onFullScreenStateChanged?(did, false)
        }
    }

    /// Determines if a specific screen currently hosts a full-screen window
    func isFullScreen(on screen: NSScreen) -> Bool {
        guard PreferencesService.shared.hideOnFullScreen else { return false }

        let screenFrame = screen.frame
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screenFrame.height

        // Convert Cocoa screen frame to Quartz coordinates (top-left is (0,0), Y grows down)
        let screenCGBounds = CGRect(
            x: screenFrame.origin.x,
            y: primaryScreenHeight - screenFrame.maxY,
            width: screenFrame.width,
            height: screenFrame.height
        )

        // 1. Check frontmost application via Accessibility API (AXFullScreen)
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           frontApp.processIdentifier != NSRunningApplication.current.processIdentifier {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

            // Check focused window first
            var focusedWindowRef: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef) == .success,
               let focusedWin = focusedWindowRef {
                let winElement = focusedWin as! AXUIElement
                if isAXWindowFullScreen(winElement, screenCGBounds: screenCGBounds) {
                    return true
                }
            }

            // Check all windows of frontmost app (in case focused element is a web player/sub-element)
            var windowsRef: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement] {
                for win in windows {
                    if isAXWindowFullScreen(win, screenCGBounds: screenCGBounds) {
                        return true
                    }
                }
            }
        }

        // 2. Check CGWindowList for borderless windows covering the screen
        // (common in games, video players, and browsers running borderless fullscreen)
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for win in windowList {
                guard let ownerPID = win[kCGWindowOwnerPID as String] as? pid_t,
                      ownerPID != NSRunningApplication.current.processIdentifier else {
                    continue
                }

                let ownerName = win[kCGWindowOwnerName as String] as? String ?? ""
                // Ignore system desktop/dock elements
                if ownerName == "Dock" || ownerName == "Window Server" || ownerName == "Wallpaper" || ownerName == "Control Center" {
                    continue
                }

                // Window layer: layer 0 is normal window, layers up to 25 cover standard desktop apps & games
                let layer = win[kCGWindowLayer as String] as? Int ?? -1
                guard layer >= 0 && layer <= 25 else { continue }

                guard let boundsDict = win[kCGWindowBounds as String] as? [String: Any],
                      let x = boundsDict["X"] as? CGFloat,
                      let y = boundsDict["Y"] as? CGFloat,
                      let w = boundsDict["Width"] as? CGFloat,
                      let h = boundsDict["Height"] as? CGFloat else {
                    continue
                }

                let winBounds = CGRect(x: x, y: y, width: w, height: h)
                let intersection = winBounds.intersection(screenCGBounds)
                if intersection.isNull { continue }

                let screenArea = screenCGBounds.width * screenCGBounds.height
                let intersectArea = intersection.width * intersection.height

                // Full screen threshold:
                // Covers at least 90% of screen area, width >= 95% of screen width,
                // and height >= screen height - 60 (to account for MacBook camera notch and menu bar)
                if intersectArea >= (screenArea * 0.90) &&
                   winBounds.width >= (screenCGBounds.width * 0.95) &&
                   winBounds.height >= (screenCGBounds.height - 60) &&
                   winBounds.minX <= (screenCGBounds.minX + 15) &&
                   winBounds.minY <= (screenCGBounds.minY + 45) {

                    // Ensure window belongs to a regular app or the active frontmost app
                    if let app = NSRunningApplication(processIdentifier: ownerPID),
                       app.activationPolicy == .regular {
                        return true
                    }
                }
            }
        }

        return false
    }

    private func isAXWindowFullScreen(_ winElement: AXUIElement, screenCGBounds: CGRect) -> Bool {
        var isFS: AnyObject?
        if AXUIElementCopyAttributeValue(winElement, "AXFullScreen" as CFString, &isFS) == .success {
            let isFullScreen: Bool
            if let fsBool = isFS as? Bool {
                isFullScreen = fsBool
            } else if let fsNum = isFS as? NSNumber {
                isFullScreen = fsNum.boolValue
            } else {
                isFullScreen = false
            }

            if isFullScreen {
                return isWindowOnScreen(winElement, screenCGBounds: screenCGBounds)
            }
        }
        return false
    }

    private func isWindowOnScreen(_ winElement: AXUIElement, screenCGBounds: CGRect) -> Bool {
        var posRef: AnyObject?
        var sizeRef: AnyObject?
        var pos = CGPoint.zero
        var size = CGSize.zero

        if AXUIElementCopyAttributeValue(winElement, kAXPositionAttribute as CFString, &posRef) == .success,
           let val = posRef {
            AXValueGetValue(val as! AXValue, .cgPoint, &pos)
        }
        if AXUIElementCopyAttributeValue(winElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
           let val = sizeRef {
            AXValueGetValue(val as! AXValue, .cgSize, &size)
        }

        let winRect = CGRect(origin: pos, size: size)
        return !winRect.intersection(screenCGBounds).isNull
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(num.uint32Value)
    }
}

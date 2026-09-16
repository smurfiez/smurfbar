import AppKit
import ApplicationServices

/// Wraps the macOS Accessibility API (AXUIElement) for window management operations.
class AccessibilityService {
    static let shared = AccessibilityService()

    private init() {}

    // MARK: - Permission Management

    /// Check if the app has Accessibility permissions.
    func isAccessibilityGranted() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt the user to grant Accessibility permissions.
    /// Opens System Settings → Privacy & Security → Accessibility.
    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Window Operations

    private func getWindowID(from element: AXUIElement) -> CGWindowID? {
        typealias FuncType = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
        guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else { return nil }
        let fn = unsafeBitCast(sym, to: FuncType.self)
        var wid: CGWindowID = 0
        if fn(element, &wid) == .success {
            return wid
        }
        return nil
    }

    /// Raise and focus a specific window of an application by its title or CGWindowID.
    func raiseWindow(pid: pid_t, windowTitle: String, windowID: CGWindowID? = nil) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)

        guard let windows = getAXWindows(for: appElement) else { return false }

        // 1. Try matching by CGWindowID if provided
        if let targetWID = windowID {
            for window in windows {
                if let wid = getWindowID(from: window), wid == targetWID {
                    bringAXWindowToFront(window, pid: pid)
                    return true
                }
            }
        }

        // 2. Try matching by title
        let cleanTarget = windowTitle.trimmingCharacters(in: .whitespaces)
        let prefixTarget = cleanTarget.replacingOccurrences(of: "…", with: "").replacingOccurrences(of: "...", with: "").trimmingCharacters(in: .whitespaces)

        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = (titleValue as? String ?? "").trimmingCharacters(in: .whitespaces)

            let isMatch: Bool
            if !cleanTarget.isEmpty && title == cleanTarget {
                isMatch = true
            } else if !prefixTarget.isEmpty && title.hasPrefix(prefixTarget) {
                isMatch = true
            } else if cleanTarget.isEmpty && windows.count == 1 {
                isMatch = true
            } else {
                isMatch = false
            }

            if isMatch {
                bringAXWindowToFront(window, pid: pid)
                return true
            }
        }

        // Fallback: if there's only 1 window or no match, activate app
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
        return false
    }

    private func bringAXWindowToFront(_ window: AXUIElement, pid: pid_t) {
        // If minimized, unminimize it
        var isMinimized: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinimized) == .success,
           let minVal = isMinimized as? Bool, minVal {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }

        // Raise window
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        // Activate the application
        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    /// Close a specific window by title or fallback to matching window element.
    func closeWindow(pid: pid_t, windowTitle: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        guard let windows = getAXWindows(for: appElement) else { return false }

        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""

            if windowTitle.isEmpty || title == windowTitle {
                var closeButtonValue: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeButtonValue) == .success,
                   let closeButton = closeButtonValue {
                    let result = AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
                    return result == .success
                }
            }
        }
        return false
    }

    /// Get a list of window titles for a given process.
    func getWindowTitles(for pid: pid_t) -> [String] {
        let appElement = AXUIElementCreateApplication(pid)
        guard let windows = getAXWindows(for: appElement) else { return [] }

        var titles: [String] = []
        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            if let title = titleValue as? String, !title.isEmpty {
                titles.append(title)
            }
        }
        return titles
    }

    /// Minimize a specific window.
    func minimizeWindow(pid: pid_t, windowTitle: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        guard let windows = getAXWindows(for: appElement) else { return false }

        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)

            if let title = titleValue as? String, title == windowTitle {
                AXUIElementSetAttributeValue(
                    window,
                    kAXMinimizedAttribute as CFString,
                    true as CFTypeRef
                )
                return true
            }
        }
        return false
    }

    /// Unminimize (restore) a specific window.
    func unminimizeWindow(pid: pid_t, windowTitle: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        guard let windows = getAXWindows(for: appElement) else { return false }

        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)

            if let title = titleValue as? String, title == windowTitle {
                AXUIElementSetAttributeValue(
                    window,
                    kAXMinimizedAttribute as CFString,
                    false as CFTypeRef
                )
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                return true
            }
        }
        return false
    }

    // MARK: - Private Helpers

    private func getAXWindows(for appElement: AXUIElement) -> [AXUIElement]? {
        var windowsValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )

        guard result == .success,
              let windows = windowsValue as? [AXUIElement]
        else { return nil }

        return windows
    }
}

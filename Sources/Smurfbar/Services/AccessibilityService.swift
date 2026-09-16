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

    /// Raise and focus a specific window of an application by its title.
    func raiseWindow(pid: pid_t, windowTitle: String) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)

        guard let windows = getAXWindows(for: appElement) else { return false }

        for window in windows {
            var titleValue: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)

            if let title = titleValue as? String, title == windowTitle {
                // Raise the window
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)

                // Activate the owning application
                if let app = NSRunningApplication(processIdentifier: pid) {
                    app.activate()
                }
                return true
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

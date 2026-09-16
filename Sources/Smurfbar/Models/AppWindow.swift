import Foundation
import CoreGraphics

/// Represents a single window belonging to a running application.
struct AppWindow: Identifiable, Equatable {
    let id: CGWindowID
    let windowID: CGWindowID
    let title: String
    let bounds: CGRect
    let isOnScreen: Bool
    let ownerPID: pid_t
    let windowLayer: Int

    init(windowID: CGWindowID, title: String, bounds: CGRect,
         isOnScreen: Bool, ownerPID: pid_t, windowLayer: Int = 0) {
        self.id = windowID
        self.windowID = windowID
        self.title = title
        self.bounds = bounds
        self.isOnScreen = isOnScreen
        self.ownerPID = ownerPID
        self.windowLayer = windowLayer
    }

    /// Create from a CGWindowList info dictionary.
    init?(from dict: [String: Any]) {
        guard let windowID = dict[kCGWindowNumber as String] as? CGWindowID,
              let ownerPID = dict[kCGWindowOwnerPID as String] as? pid_t,
              let layer = dict[kCGWindowLayer as String] as? Int,
              let boundsDict = dict[kCGWindowBounds as String] as? [String: Any]
        else {
            return nil
        }

        // Only include normal windows (layer 0)
        guard layer == 0 else { return nil }

        let title = dict[kCGWindowName as String] as? String ?? ""
        let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false

        let x = boundsDict["X"] as? CGFloat ?? 0
        let y = boundsDict["Y"] as? CGFloat ?? 0
        let width = boundsDict["Width"] as? CGFloat ?? 0
        let height = boundsDict["Height"] as? CGFloat ?? 0
        let bounds = CGRect(x: x, y: y, width: width, height: height)

        // Skip tiny windows (likely helper windows, not real UI)
        guard width > 50 && height > 50 else { return nil }

        // Real user windows are either currently on screen or, if offscreen/minimized, have a non-empty title
        guard isOnScreen || !title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }

        self.init(windowID: windowID, title: title, bounds: bounds,
                  isOnScreen: isOnScreen, ownerPID: ownerPID, windowLayer: layer)
    }
}

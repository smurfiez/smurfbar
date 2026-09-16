import AppKit
import Combine

/// Service that monitors application dock badges and unread notification counts.
class NotificationBadgeService: ObservableObject {
    static let shared = NotificationBadgeService()

    @Published var badges: [String: String] = [:] // bundleIdentifier: badge string

    private var timer: Timer?

    private init() {
        start()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.refreshBadges()
        }
        refreshBadges()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Return the badge string (e.g. "3") for an application if available
    func badge(for bundleIdentifier: String?) -> String? {
        guard let bid = bundleIdentifier else { return nil }
        return badges[bid]
    }

    /// Refresh badge strings by inspecting Dock item accessibility attributes
    func refreshBadges() {
        DispatchQueue.global(qos: .utility).async {
            let dockApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
            guard let dock = dockApps.first else { return }

            let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
            var listValue: AnyObject?
            guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &listValue) == .success,
                  let children = listValue as? [AXUIElement] else { return }

            var updatedBadges: [String: String] = [:]

            for child in children {
                var dockItems: [AXUIElement] = [child]
                var subChildrenVal: AnyObject?
                if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenVal) == .success,
                   let subChildren = subChildrenVal as? [AXUIElement] {
                    dockItems.append(contentsOf: subChildren)
                }

                for item in dockItems {
                    var titleVal: AnyObject?
                    _ = AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleVal)
                    guard let title = titleVal as? String, !title.isEmpty else { continue }

                    // Check Dock item AXBadgeLabel attribute
                    var badgeVal: AnyObject?
                    if AXUIElementCopyAttributeValue(item, "AXBadgeLabel" as CFString, &badgeVal) == .success,
                       let badgeStr = badgeVal as? String, !badgeStr.isEmpty {
                        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == title }),
                           let bundleID = app.bundleIdentifier {
                            updatedBadges[bundleID] = badgeStr
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.badges = updatedBadges
            }
        }
    }
}

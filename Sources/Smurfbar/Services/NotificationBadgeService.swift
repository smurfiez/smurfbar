import AppKit
import Combine

/// Service that monitors application dock badges, unread notifications, and user attention requests.
class NotificationBadgeService: ObservableObject {
    static let shared = NotificationBadgeService()

    @Published var badges: [String: String] = [:] // bundleIdentifier: badge string
    @Published var attentionBundleIDs: Set<String> = [] // bundleIdentifiers requesting attention
    @Published var attentionPIDs: Set<pid_t> = [] // PIDs requesting attention

    private var timer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    private init() {
        start()
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refreshBadgesAndAttention()
        }

        // Listen to workspace application activation to immediately update attention/badges
        let nc = NSWorkspace.shared.notificationCenter
        let observer = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshBadgesAndAttention()
        }
        workspaceObservers.append(observer)

        refreshBadgesAndAttention()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for obs in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        workspaceObservers.removeAll()
    }

    /// Return the badge string (e.g. "3") for an application if available
    func badge(for bundleIdentifier: String?) -> String? {
        guard let bid = bundleIdentifier else { return nil }
        return badges[bid]
    }

    /// Check if application has an active notification badge
    func hasNotification(for bundleIdentifier: String?) -> Bool {
        guard let bid = bundleIdentifier else { return false }
        if let badgeStr = badges[bid], !badgeStr.isEmpty {
            return true
        }
        return false
    }

    /// Check if application needs user attention (Dock bounce, alert, modal dialog, etc.)
    func needsAttention(for bundleIdentifier: String?, pid: pid_t? = nil) -> Bool {
        if let bid = bundleIdentifier, attentionBundleIDs.contains(bid) {
            return true
        }
        if let p = pid, attentionPIDs.contains(p) {
            return true
        }
        return false
    }

    /// Refresh badge strings and attention status
    func refreshBadgesAndAttention() {
        DispatchQueue.global(qos: .utility).async {
            let dockApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock")
            var updatedBadges: [String: String] = [:]

            if let dock = dockApps.first {
                let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
                var listValue: AnyObject?
                if AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &listValue) == .success,
                   let children = listValue as? [AXUIElement] {

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
                            let title = titleVal as? String ?? ""

                            // Check both AXStatusLabel (modern macOS) and AXBadgeLabel
                            var statusVal: AnyObject?
                            _ = AXUIElementCopyAttributeValue(item, "AXStatusLabel" as CFString, &statusVal)
                            var badgeVal: AnyObject?
                            _ = AXUIElementCopyAttributeValue(item, "AXBadgeLabel" as CFString, &badgeVal)
                            var urlVal: AnyObject?
                            _ = AXUIElementCopyAttributeValue(item, "AXURL" as CFString, &urlVal)

                            let badgeStr = (statusVal as? String) ?? (badgeVal as? String)
                            guard let badge = badgeStr, !badge.isEmpty else { continue }

                            var bundleID: String? = nil
                            if let url = urlVal as? URL {
                                bundleID = Bundle(url: url)?.bundleIdentifier
                            }
                            if bundleID == nil && !title.isEmpty {
                                bundleID = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == title })?.bundleIdentifier
                            }

                            if let bid = bundleID {
                                updatedBadges[bid] = badge
                            }
                        }
                    }
                }
            }

            // Check attention status
            let (attBundleIDs, attPIDs) = self.checkAttention()

            DispatchQueue.main.async {
                self.badges = updatedBadges
                self.attentionBundleIDs = attBundleIDs
                self.attentionPIDs = attPIDs
            }
        }
    }

    /// Check apps requesting attention via lsappinfo or modal dialogs
    private func checkAttention() -> (Set<String>, Set<pid_t>) {
        var bundleIDs = Set<String>()
        var pids = Set<pid_t>()

        // 1. Check lsappinfo find ApplicationDesiresAttention=true
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
        task.arguments = ["find", "ApplicationDesiresAttention=true"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    // Lines typically look like: ASN:0x0-0x12345-"App Name":
                    if let startQuote = line.firstIndex(of: "\""),
                       let endQuote = line[line.index(after: startQuote)...].firstIndex(of: "\"") {
                        let appName = String(line[line.index(after: startQuote)..<endQuote])
                        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) {
                            if let bid = app.bundleIdentifier {
                                bundleIDs.insert(bid)
                            }
                            pids.insert(app.processIdentifier)
                        }
                    }
                }
            }
        } catch {}

        // 2. Check background applications with modal dialogs or alert sheets
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard !app.isActive else { continue }
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            var winsVal: AnyObject?
            if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &winsVal) == .success,
               let wins = winsVal as? [AXUIElement] {
                for win in wins {
                    var modalVal: AnyObject?
                    if AXUIElementCopyAttributeValue(win, "AXModal" as CFString, &modalVal) == .success,
                       let isModal = modalVal as? Bool, isModal {
                        if let bid = app.bundleIdentifier {
                            bundleIDs.insert(bid)
                        }
                        pids.insert(app.processIdentifier)
                        break
                    }
                    var subroleVal: AnyObject?
                    if AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleVal) == .success,
                       let subrole = subroleVal as? String,
                       subrole == (kAXDialogSubrole as String) || subrole == (kAXSystemDialogSubrole as String) {
                        if let bid = app.bundleIdentifier {
                            bundleIDs.insert(bid)
                        }
                        pids.insert(app.processIdentifier)
                        break
                    }
                }
            }
        }

        return (bundleIDs, pids)
    }
}

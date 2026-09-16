import AppKit
import Combine

/// Monitors running and pinned applications and publishes updates.
/// This is the primary data source driving the taskbar's app list.
class AppMonitor: ObservableObject {
    @Published var runningApps: [RunningApp] = []
    @Published var activeAppPID: pid_t? = nil

    private var observers: [NSObjectProtocol] = []
    private var cancellables = Set<AnyCancellable>()
    private var windowRefreshTimer: Timer?

    init() {}

    // MARK: - Lifecycle

    func startMonitoring() {
        // Initial population
        refreshAppList()

        let ws = NSWorkspace.shared
        let nc = ws.notificationCenter

        // App launched
        observers.append(
            nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshAppList()
            }
        )

        // App terminated
        observers.append(
            nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshAppList()
            }
        )

        // App activated (became frontmost)
        observers.append(
            nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self = self else { return }
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self.activeAppPID = app.processIdentifier
                    self.updateActiveStates()
                }
            }
        )

        // App hidden
        observers.append(
            nc.addObserver(forName: NSWorkspace.didHideApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.updateHiddenState(pid: app.processIdentifier, isHidden: true)
                }
            }
        )

        // App unhidden
        observers.append(
            nc.addObserver(forName: NSWorkspace.didUnhideApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                    self?.updateHiddenState(pid: app.processIdentifier, isHidden: false)
                }
            }
        )

        // Observe pinned apps changes
        PinnedAppsService.shared.$pinnedApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAppList()
            }
            .store(in: &cancellables)

        // Periodically refresh window lists (every 2 seconds)
        windowRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshWindowLists()
        }
    }

    func stopMonitoring() {
        let nc = NSWorkspace.shared.notificationCenter
        for observer in observers {
            nc.removeObserver(observer)
        }
        observers.removeAll()
        cancellables.removeAll()
        windowRefreshTimer?.invalidate()
        windowRefreshTimer = nil
    }

    // MARK: - Refresh Logic

    func refreshAppList() {
        let workspace = NSWorkspace.shared
        let systemRunningApps = workspace.runningApplications.filter { app in
            app.activationPolicy == .regular
        }

        let pinnedList = PinnedAppsService.shared.pinnedApps

        // Index existing objects by id to preserve instance state
        var existingById: [String: RunningApp] = [:]
        for app in runningApps {
            existingById[app.id] = app
        }

        // Map system running apps by bundleID and by PID
        var runningByBundleID: [String: NSRunningApplication] = [:]
        for app in systemRunningApps {
            if let bundleID = app.bundleIdentifier {
                runningByBundleID[bundleID] = app
            }
        }

        var newAppList: [RunningApp] = []
        var processedRunningPIDs = Set<pid_t>()

        // 1. Add pinned apps in their configured order
        for pinned in pinnedList {
            let itemId = pinned.bundleIdentifier
            let matchingRunning = runningByBundleID[pinned.bundleIdentifier]

            if let existing = existingById[itemId] {
                // Update existing instance
                existing.isPinned = true
                if let running = matchingRunning {
                    existing.nsRunningApp = running
                    existing.pid = running.processIdentifier
                    existing.isHidden = running.isHidden
                    processedRunningPIDs.insert(running.processIdentifier)
                } else {
                    existing.nsRunningApp = nil
                    existing.pid = nil
                    existing.isActive = false
                    existing.isHidden = false
                    existing.windows = []
                }
                newAppList.append(existing)
            } else {
                // Create new instance
                if let running = matchingRunning {
                    let item = RunningApp(from: running, isPinned: true)
                    newAppList.append(item)
                    processedRunningPIDs.insert(running.processIdentifier)
                } else {
                    let item = RunningApp(from: pinned)
                    newAppList.append(item)
                }
            }
        }

        // 2. Add non-pinned running apps
        for running in systemRunningApps where !processedRunningPIDs.contains(running.processIdentifier) {
            let itemId = running.bundleIdentifier ?? "\(running.processIdentifier)"
            if let existing = existingById[itemId] {
                existing.isPinned = false
                existing.nsRunningApp = running
                existing.pid = running.processIdentifier
                existing.isHidden = running.isHidden
                newAppList.append(existing)
            } else {
                let item = RunningApp(from: running, isPinned: false)
                newAppList.append(item)
            }
        }

        // Update frontmost PID
        if let frontmost = workspace.frontmostApplication {
            activeAppPID = frontmost.processIdentifier
        }

        self.runningApps = newAppList
        updateActiveStates()
        refreshWindowLists()
    }

    private func refreshWindowLists() {
        let windowsByPID = WindowListService.shared.getWindowsByPID()
        for app in runningApps {
            if let pid = app.pid {
                app.windows = windowsByPID[pid] ?? []
            } else {
                app.windows = []
            }
        }
    }

    private func updateActiveStates() {
        for app in runningApps {
            if let pid = app.pid {
                app.isActive = (pid == activeAppPID)
            } else {
                app.isActive = false
            }
        }
    }

    private func updateHiddenState(pid: pid_t, isHidden: Bool) {
        if let app = runningApps.first(where: { $0.pid == pid }) {
            app.isHidden = isHidden
        }
    }

    /// Return apps relevant for a specific display screen
    func apps(for screen: NSScreen?) -> [RunningApp] {
        guard let screen = screen else { return runningApps }
        let isPrimary = (screen == NSScreen.main || screen == NSScreen.screens.first)

        return runningApps.filter { app in
            // Pinned apps always display on all taskbars
            if app.isPinned { return true }

            // If app has no tracked windows (e.g. background or just launched), display on primary screen
            if app.windows.isEmpty {
                return isPrimary
            }

            // Check if any of the app's windows lie on this screen
            let screenFrame = screen.frame
            return app.windows.contains { window in
                screenFrame.intersects(window.bounds)
            }
        }
    }

    /// Returns taskbar items according to screen and user's WindowGroupingMode preference
    func taskbarItems(for screen: NSScreen?) -> [TaskbarItem] {
        let baseApps = apps(for: screen)
        let mode = PreferencesService.shared.windowGroupingMode

        switch mode {
        case .alwaysCombine:
            return baseApps.map { TaskbarItem(app: $0) }

        case .neverCombine:
            var items: [TaskbarItem] = []
            for app in baseApps {
                let relevantWindows: [AppWindow]
                if let scr = screen {
                    relevantWindows = app.windows.filter { scr.frame.intersects($0.bounds) }
                } else {
                    relevantWindows = app.windows
                }

                if relevantWindows.isEmpty {
                    // App has no open windows (or is pinned / background), render single app item
                    items.append(TaskbarItem(app: app))
                } else {
                    // Each window gets its own item
                    for win in relevantWindows {
                        items.append(TaskbarItem(app: app, window: win))
                    }
                }
            }
            return items

        case .combineWhenFull:
            // If total ungrouped items would exceed 10, combine
            let totalWindows = baseApps.reduce(0) { $0 + max(1, $1.windows.count) }
            if totalWindows > 10 {
                return baseApps.map { TaskbarItem(app: $0) }
            } else {
                var items: [TaskbarItem] = []
                for app in baseApps {
                    if app.windows.isEmpty {
                        items.append(TaskbarItem(app: app))
                    } else {
                        for win in app.windows {
                            items.append(TaskbarItem(app: app, window: win))
                        }
                    }
                }
                return items
            }
        }
    }
}

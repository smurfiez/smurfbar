import AppKit
import Combine

/// Monitors running applications using NSWorkspace and publishes updates.
/// This is the main data source driving the taskbar's app list.
class AppMonitor: ObservableObject {
    @Published var runningApps: [RunningApp] = []
    @Published var activeAppPID: pid_t? = nil

    private var observers: [NSObjectProtocol] = []
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
            nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                self?.refreshAppList()
            }
        )

        // App terminated
        observers.append(
            nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
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
        windowRefreshTimer?.invalidate()
        windowRefreshTimer = nil
    }

    // MARK: - Refresh Logic

    private func refreshAppList() {
        let workspace = NSWorkspace.shared
        let apps = workspace.runningApplications.filter { app in
            // Only show regular apps (not background agents/daemons)
            app.activationPolicy == .regular
        }

        // Track current PIDs to detect changes
        let currentPIDs = Set(runningApps.map { $0.pid })
        let newPIDs = Set(apps.map { $0.processIdentifier })

        // Remove terminated apps
        runningApps.removeAll { !newPIDs.contains($0.pid) }

        // Add new apps
        for app in apps where !currentPIDs.contains(app.processIdentifier) {
            let runningApp = RunningApp(from: app)
            runningApps.append(runningApp)
        }

        // Set active app
        if let frontmost = workspace.frontmostApplication {
            activeAppPID = frontmost.processIdentifier
        }
        updateActiveStates()

        // Refresh window lists for all apps
        refreshWindowLists()
    }

    private func refreshWindowLists() {
        let windowsByPID = WindowListService.shared.getWindowsByPID()
        for app in runningApps {
            app.windows = windowsByPID[app.pid] ?? []
        }
    }

    private func updateActiveStates() {
        for app in runningApps {
            app.isActive = (app.pid == activeAppPID)
        }
    }

    private func updateHiddenState(pid: pid_t, isHidden: Bool) {
        if let app = runningApps.first(where: { $0.pid == pid }) {
            app.isHidden = isHidden
        }
    }
}

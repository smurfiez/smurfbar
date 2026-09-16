import AppKit
import Combine

/// Manages multiple taskbar instances across connected displays.
class MultiMonitorService: ObservableObject {
    static var shared: MultiMonitorService?

    private var appMonitor: AppMonitor
    private var controllers: [CGDirectDisplayID: TaskbarWindowController] = [:]
    private var screenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()
    private var isVisible: Bool = true

    init(appMonitor: AppMonitor) {
        self.appMonitor = appMonitor
        MultiMonitorService.shared = self
    }

    /// Primary taskbar window controller (for status bar menu item interactions)
    var primaryController: TaskbarWindowController? {
        guard let primaryScreen = NSScreen.main ?? NSScreen.screens.first,
              let displayID = displayID(for: primaryScreen) else {
            return controllers.values.first
        }
        return controllers[displayID]
    }

    func setup() {
        rebuildTaskbars()

        // Observe screen configuration changes
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildTaskbars()
        }

        // Observe multi-monitor mode changes
        PreferencesService.shared.$multiMonitorMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildTaskbars()
            }
            .store(in: &cancellables)
    }

    func teardown() {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        cancellables.removeAll()

        for (_, controller) in controllers {
            controller.hideTaskbar()
        }
        controllers.removeAll()
    }

    /// Reconcile taskbars with currently connected screens based on user preference
    func rebuildTaskbars() {
        let prefs = PreferencesService.shared
        let screens: [NSScreen]

        if prefs.multiMonitorMode == .allMonitors {
            screens = NSScreen.screens
        } else {
            if let primary = NSScreen.main ?? NSScreen.screens.first {
                screens = [primary]
            } else {
                screens = []
            }
        }

        var activeDisplayIDs = Set<CGDirectDisplayID>()

        for screen in screens {
            guard let did = displayID(for: screen) else { continue }
            activeDisplayIDs.insert(did)

            if let existing = controllers[did] {
                existing.updateScreen(screen)
                if isVisible && existing.panel?.isVisible != true {
                    existing.showTaskbar()
                }
            } else {
                let controller = TaskbarWindowController(screen: screen, appMonitor: appMonitor)
                controllers[did] = controller
                if isVisible {
                    controller.showTaskbar()
                }
            }
        }

        // Remove disconnected or unneeded controllers
        let existingIDs = Array(controllers.keys)
        for did in existingIDs where !activeDisplayIDs.contains(did) {
            controllers[did]?.hideTaskbar()
            controllers.removeValue(forKey: did)
        }
    }

    /// Toggle visibility across all active taskbars
    func toggleTaskbars() {
        isVisible.toggle()
        if isVisible {
            for controller in controllers.values {
                controller.showTaskbar()
            }
        } else {
            for controller in controllers.values {
                controller.hideTaskbar()
            }
        }
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(num.uint32Value)
    }
}

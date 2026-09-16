import AppKit

/// Kind of item rendered on the taskbar.
enum TaskbarItemKind: Equatable {
    case app(RunningApp)
    case window(RunningApp, AppWindow)
}

/// Unified presentation item representing either a grouped app tile or an individual window button.
struct TaskbarItem: Identifiable, Equatable {
    let id: String
    let kind: TaskbarItemKind
    let runningApp: RunningApp
    let window: AppWindow?

    var localizedName: String {
        runningApp.localizedName
    }

    var title: String {
        if let win = window, !win.title.trimmingCharacters(in: .whitespaces).isEmpty {
            return win.title
        }
        return runningApp.localizedName
    }

    var icon: NSImage {
        runningApp.icon
    }

    var pid: pid_t? {
        runningApp.pid
    }

    var isRunning: Bool {
        runningApp.isRunning
    }

    var isPinned: Bool {
        runningApp.isPinned
    }

    var isHidden: Bool {
        runningApp.isHidden
    }

    var bundleIdentifier: String? {
        runningApp.bundleIdentifier
    }

    init(app: RunningApp) {
        self.id = app.id
        self.kind = .app(app)
        self.runningApp = app
        self.window = nil
    }

    init(app: RunningApp, window: AppWindow) {
        self.id = "\(app.id)_win_\(window.id)"
        self.kind = .window(app, window)
        self.runningApp = app
        self.window = window
    }

    static func == (lhs: TaskbarItem, rhs: TaskbarItem) -> Bool {
        lhs.id == rhs.id
    }
}

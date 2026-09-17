import AppKit
import SwiftUI

/// Window controller for the Preferences / Settings window.
class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Smurfbar Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: PreferencesView())
        window.contentView = hostingView

        if let icon = AppIconProvider.shared.iconImage {
            window.miniwindowImage = icon
        }

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPreferences() {
        guard let window = self.window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

import AppKit

/// Menu bar status item controller.
/// Since Smurfbar is an LSUIElement (no Dock icon), the status item is the
/// primary way for the user to access preferences and quit.
class StatusBarController {
    private var statusItem: NSStatusItem?
    private weak var windowController: TaskbarWindowController?

    init(windowController: TaskbarWindowController) {
        self.windowController = windowController
    }

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.bottomhalf.filled",
                                   accessibilityDescription: "Smurfbar")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        statusItem?.menu = buildMenu()
    }

    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let aboutItem = NSMenuItem(title: "About Smurfbar", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Toggle Taskbar", action: #selector(toggleTaskbar), keyEquivalent: "t")
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let restoreDockItem = NSMenuItem(title: "Restore Dock", action: #selector(restoreDock), keyEquivalent: "")
        restoreDockItem.target = self
        menu.addItem(restoreDockItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Smurfbar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Smurfbar"
        alert.informativeText = "A Windows-style taskbar for macOS.\n\nVersion 0.1.0"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func toggleTaskbar() {
        windowController?.toggleTaskbar()
    }

    @objc private func restoreDock() {
        DockService.shared.restoreDock()
    }

    @objc private func quitApp() {
        // Restore Dock before quitting
        DockService.shared.restoreDock()
        NSApp.terminate(nil)
    }
}

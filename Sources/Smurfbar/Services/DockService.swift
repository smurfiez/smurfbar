import Foundation

/// Manages the macOS Dock visibility.
/// Auto-hides the Dock when Smurfbar launches and restores it on quit.
class DockService {
    static let shared = DockService()

    private var dockWasAutohidden: Bool = false

    private init() {
        // Remember the original Dock autohide state
        dockWasAutohidden = isDockAutohideEnabled()
    }

    /// Enable Dock auto-hide (hides the Dock so Smurfbar replaces it).
    func hideDock() {
        guard !isDockAutohideEnabled() else { return }
        setDockAutohide(enabled: true)
    }

    /// Restore the Dock to its original state before Smurfbar launched.
    func restoreDock() {
        if !dockWasAutohidden {
            setDockAutohide(enabled: false)
        }
    }

    /// Check if the Dock is currently set to auto-hide.
    func isDockAutohideEnabled() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.dock", "autohide"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "1"
    }

    // MARK: - Private

    private func setDockAutohide(enabled: Bool) {
        let defaults = Process()
        defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaults.arguments = ["write", "com.apple.dock", "autohide", "-bool", enabled ? "true" : "false"]

        do {
            try defaults.run()
            defaults.waitUntilExit()
        } catch {
            print("⚠️ Failed to set Dock autohide: \(error)")
            return
        }

        // Restart the Dock to apply the change
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["Dock"]

        do {
            try killall.run()
            killall.waitUntilExit()
        } catch {
            print("⚠️ Failed to restart Dock: \(error)")
        }
    }
}

import Foundation
import AppKit
import Combine

/// Service responsible for managing pinned applications on the taskbar.
/// Persists pinned apps to UserDefaults.
class PinnedAppsService: ObservableObject {
    static let shared = PinnedAppsService()

    private let userDefaultsKey = "Smurfbar_PinnedApps"

    @Published var pinnedApps: [PinnedApp] = [] {
        didSet {
            savePinnedApps()
        }
    }

    private init() {
        loadPinnedApps()
    }

    // MARK: - Persistence

    private func loadPinnedApps() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([PinnedApp].self, from: data) {
            self.pinnedApps = decoded
        } else {
            // Default pinned apps on first run
            self.pinnedApps = defaultPinnedApps()
            savePinnedApps()
        }
    }

    private func savePinnedApps() {
        if let data = try? JSONEncoder().encode(pinnedApps) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func defaultPinnedApps() -> [PinnedApp] {
        let defaults: [(id: String, name: String)] = [
            ("com.apple.Safari", "Safari"),
            ("com.apple.finder", "Finder"),
            ("com.apple.Terminal", "Terminal"),
            ("com.apple.systempreferences", "System Settings")
        ]

        return defaults.compactMap { item in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.id) else {
                return nil
            }
            return PinnedApp(
                bundleIdentifier: item.id,
                localizedName: item.name,
                bundlePath: url.path
            )
        }
    }

    // MARK: - Query & Mutation

    func isPinned(bundleIdentifier: String) -> Bool {
        pinnedApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func pinApp(bundleIdentifier: String, localizedName: String, bundlePath: String? = nil) {
        guard !isPinned(bundleIdentifier: bundleIdentifier) else { return }

        let path = bundlePath ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)?.path
        let pinned = PinnedApp(
            bundleIdentifier: bundleIdentifier,
            localizedName: localizedName,
            bundlePath: path
        )
        pinnedApps.append(pinned)
    }

    func unpinApp(bundleIdentifier: String) {
        pinnedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
    }

    func togglePin(bundleIdentifier: String, localizedName: String, bundlePath: String? = nil) {
        if isPinned(bundleIdentifier: bundleIdentifier) {
            unpinApp(bundleIdentifier: bundleIdentifier)
        } else {
            pinApp(bundleIdentifier: bundleIdentifier, localizedName: localizedName, bundlePath: bundlePath)
        }
    }

    func movePinnedApp(fromIndex: Int, toIndex: Int) {
        guard fromIndex >= 0, fromIndex < pinnedApps.count,
              toIndex >= 0, toIndex < pinnedApps.count,
              fromIndex != toIndex else { return }
        let item = pinnedApps.remove(at: fromIndex)
        pinnedApps.insert(item, at: toIndex)
    }

    func movePinnedApp(bundleIdentifier: String, toIndex: Int) {
        guard let currentIndex = pinnedApps.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) else { return }
        movePinnedApp(fromIndex: currentIndex, toIndex: toIndex)
    }

    // MARK: - Launching

    func launchApp(_ pinnedApp: PinnedApp) {
        guard let url = pinnedApp.bundleURL else {
            print("⚠️ Cannot launch \(pinnedApp.localizedName): bundle URL not found")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                print("❌ Failed to launch \(pinnedApp.localizedName): \(error.localizedDescription)")
            }
        }
    }
}

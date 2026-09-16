import Foundation
import AppKit

/// Discovered application item representation for the Start Menu.
struct DiscoveredApp: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let url: URL
    let icon: NSImage

    static func == (lhs: DiscoveredApp, rhs: DiscoveredApp) -> Bool {
        lhs.id == rhs.id
    }
}

/// Service that discovers and indexes applications installed on the system.
class AppDiscoveryService: ObservableObject {
    static let shared = AppDiscoveryService()

    @Published var apps: [DiscoveredApp] = []
    @Published var isIndexing: Bool = false

    private init() {
        indexApplications()
    }

    /// Asynchronously index apps from standard macOS application locations
    func indexApplications() {
        guard !isIndexing else { return }
        isIndexing = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let searchDirectories: [URL] = [
                URL(fileURLWithPath: "/Applications"),
                URL(fileURLWithPath: "/Applications/Utilities"),
                URL(fileURLWithPath: "/System/Applications"),
                URL(fileURLWithPath: "/System/Applications/Utilities"),
                FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            ]

            var seenBundleIDs = Set<String>()
            var seenPaths = Set<String>()
            var foundApps: [DiscoveredApp] = []

            let fileManager = FileManager.default

            for directory in searchDirectories {
                guard fileManager.fileExists(atPath: directory.path) else { continue }

                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.isApplicationKey, .isRegularFileKey],
                    options: [.skipsSubdirectoryDescendants, .skipsPackageDescendants]
                )

                while let fileURL = enumerator?.nextObject() as? URL {
                    if fileURL.pathExtension == "app" {
                        self?.processAppBundle(
                            url: fileURL,
                            seenBundleIDs: &seenBundleIDs,
                            seenPaths: &seenPaths,
                            into: &foundApps
                        )
                    }
                }
            }

            // Sort alphabetically by localized name
            foundApps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            DispatchQueue.main.async {
                self?.apps = foundApps
                self?.isIndexing = false
            }
        }
    }

    private func processAppBundle(
        url: URL,
        seenBundleIDs: inout Set<String>,
        seenPaths: inout Set<String>,
        into list: inout [DiscoveredApp]
    ) {
        let path = url.path
        guard !seenPaths.contains(path) else { return }
        seenPaths.insert(path)

        guard let bundle = Bundle(url: url) else { return }
        let bundleID = bundle.bundleIdentifier

        if let bundleID = bundleID {
            guard !seenBundleIDs.contains(bundleID) else { return }
            seenBundleIDs.insert(bundleID)
        }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent

        // Skip internal or auxiliary helpers
        if displayName.hasPrefix(".") || displayName.isEmpty {
            return
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)

        let app = DiscoveredApp(
            id: bundleID ?? path,
            name: displayName,
            bundleIdentifier: bundleID,
            url: url,
            icon: icon
        )
        list.append(app)
    }

    /// Search applications by query
    func search(query: String) -> [DiscoveredApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }

        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// Launch an application
    func launch(_ app: DiscoveredApp) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: config) { _, error in
            if let error = error {
                print("❌ Failed to launch \(app.name): \(error.localizedDescription)")
            }
        }
    }
}

import Foundation
import AppKit

/// Model representing a pinned application in the taskbar.
struct PinnedApp: Identifiable, Codable, Equatable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    let localizedName: String
    let bundlePath: String?

    var bundleURL: URL? {
        if let bundlePath = bundlePath {
            return URL(fileURLWithPath: bundlePath)
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    var icon: NSImage {
        if let url = bundleURL {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}

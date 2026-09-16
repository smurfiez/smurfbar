import AppKit

/// Represents a recently accessed document or file for an application.
struct RecentDocument: Identifiable, Equatable {
    let id: String
    let url: URL
    let title: String
    let icon: NSImage

    init(url: URL) {
        self.id = url.path
        self.url = url
        self.title = url.lastPathComponent
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 16, height: 16)
        self.icon = img
    }
}

/// Service that discovers and manages recent documents and jump list actions for applications.
class RecentDocumentsService {
    static let shared = RecentDocumentsService()

    private var cache: [String: [RecentDocument]] = [:]

    private init() {}

    /// Get recent documents for a specific app bundle identifier
    func recentDocuments(for bundleIdentifier: String) -> [RecentDocument] {
        if let cached = cache[bundleIdentifier], !cached.isEmpty {
            return cached
        }

        var docs: [RecentDocument] = []

        // Query NSDocumentController recent document URLs
        let recents = NSDocumentController.shared.recentDocumentURLs
        for url in recents {
            if let appURL = NSWorkspace.shared.urlForApplication(toOpen: url),
               let bundle = Bundle(url: appURL)?.bundleIdentifier,
               bundle == bundleIdentifier {
                docs.append(RecentDocument(url: url))
            }
        }

        let result = Array(docs.prefix(6))
        if !result.isEmpty {
            cache[bundleIdentifier] = result
        }
        return result
    }

    /// Open a recent document with the designated application
    func openDocument(_ doc: RecentDocument, with bundleIdentifier: String?) {
        if let bundleID = bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.open([doc.url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(doc.url)
        }
    }
}

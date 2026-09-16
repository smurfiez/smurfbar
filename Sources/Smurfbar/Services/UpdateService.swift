import AppKit
import Foundation
import Combine

/// GitHub Release Asset representation
struct GitHubReleaseAsset: Codable {
    let name: String
    let browserDownloadUrl: String
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
        case size
    }
}

/// GitHub Release model from repository API
struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let assets: [GitHubReleaseAsset]?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case assets
    }

    var cleanVersion: String {
        var tag = tagName
        if tag.lowercased().hasPrefix("v") {
            tag.removeFirst()
        }
        return tag
    }
}

/// Manages checking for and downloading updates from GitHub releases.
class UpdateService: ObservableObject {
    static let shared = UpdateService()

    private let repoOwner = "smurfiez"
    private let repoName = "smurfbar"

    @Published var isChecking: Bool = false
    @Published var updateAvailable: Bool = false
    @Published var latestRelease: GitHubRelease?
    @Published var statusMessage: String = "Not checked yet"
    @Published var lastCheckedDate: Date?
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5.0"
    }

    private init() {
        if PreferencesService.shared.autoCheckUpdates {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.checkForUpdates(manual: false)
            }
        }
    }

    /// Check GitHub releases for updates
    func checkForUpdates(manual: Bool = false) {
        guard !isChecking else { return }

        DispatchQueue.main.async {
            self.isChecking = true
            self.statusMessage = "Checking for updates..."
        }

        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                self.isChecking = false
                self.statusMessage = "Invalid update URL"
            }
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("Smurfbar-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isChecking = false
                self.lastCheckedDate = Date()

                if let error = error {
                    self.statusMessage = "Check failed: \(error.localizedDescription)"
                    if manual {
                        self.showAlert(title: "Update Check Failed", message: "Could not connect to GitHub: \(error.localizedDescription)")
                    }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    self.statusMessage = "Invalid server response"
                    return
                }

                if httpResponse.statusCode == 404 {
                    self.updateAvailable = false
                    self.statusMessage = "Smurfbar is up to date (no releases published yet)."
                    if manual {
                        self.showAlert(title: "You're Up to Date!", message: "Smurfbar \(self.currentVersion) is currently the newest version.")
                    }
                    return
                }

                guard httpResponse.statusCode == 200, let data = data else {
                    self.statusMessage = "Server returned status code \(httpResponse.statusCode)"
                    return
                }

                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self.latestRelease = release

                    let isNewer = self.isVersion(release.cleanVersion, newerThan: self.currentVersion)
                    self.updateAvailable = isNewer

                    if isNewer {
                        self.statusMessage = "A new version (v\(release.cleanVersion)) is available!"
                        if manual {
                            self.showUpdatePrompt(release: release)
                        }
                    } else {
                        self.statusMessage = "Smurfbar is up to date (v\(self.currentVersion))."
                        if manual {
                            self.showAlert(title: "You're Up to Date!", message: "Smurfbar \(self.currentVersion) is currently the newest version.")
                        }
                    }
                } catch {
                    self.statusMessage = "Failed to parse release information"
                    if manual {
                        self.showAlert(title: "Update Error", message: "Failed to read release details from GitHub.")
                    }
                }
            }
        }.resume()
    }

    /// Compare semantic versions
    private func isVersion(_ remote: String, newerThan current: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let count = max(remoteParts.count, currentParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let c = i < currentParts.count ? currentParts[i] : 0
            if r > c { return true }
            if r < c { return false }
        }
        return false
    }

    /// Open release web page
    func openReleasePage(release: GitHubRelease? = nil) {
        let target = release ?? latestRelease
        if let target = target, let url = URL(string: target.htmlUrl) {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
            NSWorkspace.shared.open(fallback)
        }
    }

    /// Download the update asset or open GitHub releases page
    func downloadAndInstallUpdate(release: GitHubRelease? = nil) {
        let target = release ?? latestRelease
        guard let target = target else {
            openReleasePage()
            return
        }

        // Prefer .zip for automatic in-place installation, fallback to .dmg
        if let asset = target.assets?.first(where: { $0.name.hasSuffix(".zip") }) ??
                       target.assets?.first(where: { $0.name.hasSuffix(".dmg") }),
           let downloadURL = URL(string: asset.browserDownloadUrl) {
            startDownload(url: downloadURL, filename: asset.name)
        } else {
            openReleasePage(release: target)
        }
    }

    private func startDownload(url: URL, filename: String) {
        self.isDownloading = true
        self.downloadProgress = 0.0

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isDownloading = false
                if let error = error {
                    self.showAlert(title: "Download Failed", message: error.localizedDescription)
                    return
                }

                guard let tempURL = tempURL else { return }

                do {
                    let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                    let destinationURL = downloadsDir.appendingPathComponent(filename)

                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }

                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                    if filename.hasSuffix(".zip") {
                        self.promptInstallAndRelaunch(zipURL: destinationURL)
                    } else {
                        NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
                        self.showAlert(
                            title: "Download Complete",
                            message: "The update has been downloaded to your Downloads folder: \(filename)"
                        )
                    }
                } catch {
                    self.showAlert(title: "Save Failed", message: error.localizedDescription)
                }
            }
        }
        task.resume()
    }

    private func promptInstallAndRelaunch(zipURL: URL) {
        let alert = NSAlert()
        alert.messageText = "Update Downloaded"
        alert.informativeText = "Smurfbar update (\(zipURL.lastPathComponent)) is ready. Would you like to install and relaunch now?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Install & Relaunch")
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            installAndRelaunch(zipURL: zipURL)
        } else if response == .alertSecondButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([zipURL])
        }
    }

    private func installAndRelaunch(zipURL: URL) {
        let tempExtractDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        do {
            try FileManager.default.createDirectory(at: tempExtractDir, withIntermediateDirectories: true)

            // Extract archive using ditto
            let ditto = Process()
            ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            ditto.arguments = ["-x", "-k", zipURL.path, tempExtractDir.path]
            try ditto.run()
            ditto.waitUntilExit()

            // Find .app inside tempExtractDir
            let contents = try FileManager.default.contentsOfDirectory(at: tempExtractDir, includingPropertiesForKeys: nil)
            guard let newAppURL = contents.first(where: { $0.pathExtension == "app" }) else {
                showAlert(title: "Installation Failed", message: "Could not find Smurfbar.app inside downloaded archive.")
                return
            }

            // Determine target installation path
            let currentBundlePath = Bundle.main.bundleURL.path
            let targetPath: String
            if currentBundlePath.hasPrefix("/Applications") {
                targetPath = currentBundlePath
            } else {
                targetPath = "/Applications/Smurfbar.app"
            }

            let pid = ProcessInfo.processInfo.processIdentifier
            let script = """
            while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
            rm -rf "\(targetPath)"
            cp -R "\(newAppURL.path)" "\(targetPath)"
            rm -rf "\(tempExtractDir.path)"
            open "\(targetPath)"
            """

            let scriptURL = tempExtractDir.appendingPathComponent("update.sh")
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)

            let chmod = Process()
            chmod.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmod.arguments = ["+x", scriptURL.path]
            try chmod.run()
            chmod.waitUntilExit()

            let launcher = Process()
            launcher.executableURL = URL(fileURLWithPath: "/bin/sh")
            launcher.arguments = [scriptURL.path]
            try launcher.run()

            // Restore dock and terminate so update script can swap and launch
            DockService.shared.restoreDock()
            NSApp.terminate(nil)
        } catch {
            showAlert(title: "Installation Failed", message: "Failed to install update: \(error.localizedDescription)")
        }
    }

    // MARK: - Alerts

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showUpdatePrompt(release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "Update Available: Smurfbar \(release.tagName)"
        var bodyText = "A new version of Smurfbar is available.\n\n"
        if let body = release.body, !body.isEmpty {
            bodyText += "Release Notes:\n\(body.prefix(300))\n\n"
        }
        bodyText += "Would you like to download it now?"
        alert.informativeText = bodyText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download Update")
        alert.addButton(withTitle: "View on GitHub")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            downloadAndInstallUpdate(release: release)
        } else if response == .alertSecondButtonReturn {
            openReleasePage(release: release)
        }
    }
}

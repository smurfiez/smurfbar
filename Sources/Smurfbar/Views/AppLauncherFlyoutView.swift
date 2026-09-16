import SwiftUI
import AppKit

/// Start menu / App launcher flyout view.
struct AppLauncherFlyoutView: View {
    @ObservedObject var discoveryService = AppDiscoveryService.shared
    let onClose: () -> Void
    let onOpenPreferences: () -> Void

    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool

    var filteredApps: [DiscoveredApp] {
        discoveryService.search(query: searchQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: Search Bar
            searchHeader
                .padding(12)

            Divider()

            // Main: Apps List / Grid
            appsSection

            Divider()

            // Footer: User & Power Controls
            footerBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 360, height: 480)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 16, y: -6)
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Subviews

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search applications...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    if let firstApp = filteredApps.first {
                        launchApp(firstApp)
                    }
                }

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var appsSection: some View {
        ScrollView(.vertical, showsIndicators: true) {
            if discoveryService.isIndexing && discoveryService.apps.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading applications...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.app.dashed")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No applications found")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(filteredApps) { app in
                        AppLauncherItemView(app: app) {
                            launchApp(app)
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    private var footerBar: some View {
        HStack {
            // User / App indicator
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                Text(NSUserName())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Quick actions
            HStack(spacing: 12) {
                Button(action: {
                    onClose()
                    onOpenPreferences()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button(action: lockScreen) {
                    Image(systemName: "lock")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Lock Screen")

                Button(action: sleepMac) {
                    Image(systemName: "moon")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Sleep")

                Button(action: promptPowerAction) {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Shut Down / Restart...")
            }
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func launchApp(_ app: DiscoveredApp) {
        onClose()
        discoveryService.launch(app)
    }

    private func lockScreen() {
        onClose()
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "tell application \"System Events\" to sleep"]
        try? task.run()
    }

    private func sleepMac() {
        onClose()
        let script = "tell application \"System Events\" to sleep"
        NSAppleScript(source: script)?.executeAndReturnError(nil)
    }

    private func promptPowerAction() {
        onClose()
        let alert = NSAlert()
        alert.messageText = "Power Options"
        alert.informativeText = "Choose a system power action:"
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Shut Down")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSAppleScript(source: "tell application \"System Events\" to restart")?.executeAndReturnError(nil)
        } else if response == .alertSecondButtonReturn {
            NSAppleScript(source: "tell application \"System Events\" to shut down")?.executeAndReturnError(nil)
        }
    }
}

/// A single application item in the launcher grid.
struct AppLauncherItemView: View {
    let app: DiscoveredApp
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            Text(app.name)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isHovered ? Color.primary.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .contextMenu {
            Button("Open") {
                onSelect()
            }

            Divider()

            if let bundleID = app.bundleIdentifier {
                if PinnedAppsService.shared.isPinned(bundleIdentifier: bundleID) {
                    Button("Unpin from Taskbar") {
                        PinnedAppsService.shared.unpinApp(bundleIdentifier: bundleID)
                    }
                } else {
                    Button("Pin to Taskbar") {
                        PinnedAppsService.shared.pinApp(
                            bundleIdentifier: bundleID,
                            localizedName: app.name,
                            bundlePath: app.url.path
                        )
                    }
                }
            }

            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
        }
    }
}

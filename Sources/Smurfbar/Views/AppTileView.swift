import SwiftUI
import UniformTypeIdentifiers

/// An individual app or window tile in the taskbar.
/// Shows the icon, title/labels, notification badges, active indicator, and handles Jump Lists.
struct AppTileView: View {
    let item: TaskbarItem
    @ObservedObject var app: RunningApp
    @ObservedObject var prefs = PreferencesService.shared
    @ObservedObject var badgeService = NotificationBadgeService.shared
    let isActive: Bool
    let onTap: () -> Void
    let onRightClick: () -> Void
    var onHover: ((Bool) -> Void)? = nil
    var onReorder: ((String) -> Void)? = nil

    @State private var isHovered: Bool = false
    @State private var isDropTarget: Bool = false

    init(item: TaskbarItem, isActive: Bool, onTap: @escaping () -> Void, onRightClick: @escaping () -> Void, onHover: ((Bool) -> Void)? = nil, onReorder: ((String) -> Void)? = nil) {
        self.item = item
        self.app = item.runningApp
        self.isActive = isActive
        self.onTap = onTap
        self.onRightClick = onRightClick
        self.onHover = onHover
        self.onReorder = onReorder
    }

    init(app: RunningApp, isActive: Bool, onTap: @escaping () -> Void, onRightClick: @escaping () -> Void, onHover: ((Bool) -> Void)? = nil, onReorder: ((String) -> Void)? = nil) {
        self.init(item: TaskbarItem(app: app), isActive: isActive, onTap: onTap, onRightClick: onRightClick, onHover: onHover, onReorder: onReorder)
    }

    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 6) {
                // App icon with notification badge
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)

                    if let badge = badgeService.badge(for: item.bundleIdentifier) {
                        Text(badge)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 5, y: -4)
                    }
                }

                // Title / Label (shown if app labels enabled or if ungrouped window button)
                if prefs.showAppLabels || item.window != nil {
                    Text(item.title)
                        .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundColor(isActive ? .primary : (app.isRunning ? .secondary : .secondary.opacity(0.8)))
                        .frame(maxWidth: item.window != nil ? 140 : 110, alignment: .leading)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(height: 36)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isDropTarget ? prefs.accentColorChoice.color : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Indicator: active accent bar or running dot (top or bottom based on taskbar position)
                VStack {
                    if prefs.taskbarPosition == .top {
                        indicatorBar
                        Spacer()
                    } else {
                        Spacer()
                        indicatorBar
                    }
                }
            )
            .opacity(app.isHidden ? 0.5 : (app.isRunning ? 1.0 : 0.85))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            onHover?(hovering)
        }
        .onDrag {
            NSItemProvider(object: "smurfbar-tile:\(item.id)" as NSString)
        }
        .onDrop(of: [.plainText, .fileURL], isTargeted: $isDropTarget) { providers in
            handleDrop(providers: providers)
        }
        .contextMenu {
            appContextMenu
        }
        .help(prefs.showWindowPreviews && app.isRunning && !app.windows.isEmpty ? "" : tooltipText)
    }

    // MARK: - Subviews

    private var hasNotification: Bool {
        badgeService.hasNotification(for: item.bundleIdentifier)
    }

    private var needsAttention: Bool {
        badgeService.needsAttention(for: item.bundleIdentifier, pid: app.pid)
    }

    @ViewBuilder
    private var indicatorBar: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 1)
                .fill(prefs.accentColorChoice.color)
                .frame(height: 2)
                .padding(.horizontal, 8)
                .padding(prefs.taskbarPosition == .top ? .top : .bottom, 1)
        } else if prefs.runningIndicatorMode != .never && needsAttention {
            Circle()
                .fill(Color.orange)
                .frame(width: 5, height: 5)
                .shadow(color: Color.orange.opacity(0.6), radius: 2)
                .padding(prefs.taskbarPosition == .top ? .top : .bottom, 2)
        } else if prefs.runningIndicatorMode != .never && hasNotification {
            Circle()
                .fill(Color.red)
                .frame(width: 5, height: 5)
                .shadow(color: Color.red.opacity(0.6), radius: 2)
                .padding(prefs.taskbarPosition == .top ? .top : .bottom, 2)
        } else if prefs.runningIndicatorMode == .always && app.isRunning {
            Circle()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 4, height: 4)
                .padding(prefs.taskbarPosition == .top ? .top : .bottom, 2)
        }
    }

    private var tileBackground: some View {
        Group {
            if isDropTarget {
                prefs.accentColorChoice.color.opacity(0.2)
            } else if isActive {
                Color.primary.opacity(0.12)
            } else if isHovered {
                Color.primary.opacity(0.06)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private var appContextMenu: some View {
        // 1. Jump List Quick Tasks
        Button("New Window") {
            AppActionService.shared.openNewWindow(for: app)
        }

        if isWebBrowser(app.bundleIdentifier) {
            Button("New Private Window") {
                AppActionService.shared.openNewPrivateWindow(for: app)
            }
        }

        // 2. Recent Documents Jump List
        if let bundleID = app.bundleIdentifier {
            let recents = RecentDocumentsService.shared.recentDocuments(for: bundleID)
            if !recents.isEmpty {
                Divider()
                ForEach(recents) { doc in
                    Button(doc.title) {
                        RecentDocumentsService.shared.openDocument(doc, with: bundleID)
                    }
                }
            }
        }

        Divider()

        // 3. Window Specific Actions (if in Never Combine mode)
        if let window = item.window {
            Button("Close Window") {
                if let pid = app.pid {
                    _ = AccessibilityService.shared.closeWindow(pid: pid, windowTitle: window.title)
                }
            }
            Button("Minimize Window") {
                if let pid = app.pid {
                    _ = AccessibilityService.shared.minimizeWindow(pid: pid, windowTitle: window.title)
                }
            }
            Divider()
        }

        // 4. Standard App Controls
        if app.isRunning {
            Button("Show All Windows") {
                AppActionService.shared.activateApp(app)
            }

            if app.isHidden {
                Button("Unhide") {
                    AppActionService.shared.unhideApp(app)
                }
            } else {
                Button("Hide") {
                    AppActionService.shared.hideApp(app)
                }
            }
        } else {
            Button("Open") {
                AppActionService.shared.launchApp(app)
            }
        }

        Divider()

        // Pin / Unpin
        if app.isPinned {
            Button("Unpin from Taskbar") {
                AppActionService.shared.togglePin(for: app)
            }
        } else {
            Button("Pin to Taskbar") {
                AppActionService.shared.togglePin(for: app)
            }
        }

        Divider()

        Button("Show in Finder") {
            AppActionService.shared.showInFinder(app)
        }

        if app.isRunning {
            Divider()

            Button("Quit \(app.localizedName)") {
                AppActionService.shared.quitApp(app)
            }

            Button("Force Quit") {
                AppActionService.shared.forceQuitApp(app)
            }
        }
    }

    private func isWebBrowser(_ bundleID: String?) -> Bool {
        guard let bid = bundleID else { return false }
        return bid.contains("Safari") || bid.contains("Chrome") || bid.contains("Firefox") || bid.contains("Brave")
    }

    private var tooltipText: String {
        var tooltip = app.localizedName
        if !app.isRunning {
            tooltip += " (Pinned)"
            return tooltip
        }
        if app.isHidden {
            tooltip += " (Hidden)"
        }
        let windowCount = app.windows.count
        if windowCount > 0 {
            tooltip += " — \(windowCount) window\(windowCount == 1 ? "" : "s")"
        }
        return tooltip
    }

    // MARK: - Drag & Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        // 1. Check for taskbar tile reordering
        for provider in providers {
            _ = provider.loadObject(ofClass: String.self) { string, _ in
                if let str = string, str.hasPrefix("smurfbar-tile:") {
                    let sourceID = str.replacingOccurrences(of: "smurfbar-tile:", with: "")
                    DispatchQueue.main.async {
                        self.onReorder?(sourceID)
                    }
                }
            }
        }

        // 2. Check for Finder file URLs
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    urls.append(url)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                AppActionService.shared.openFiles(urls, with: self.app)
            }
        }

        return true
    }
}

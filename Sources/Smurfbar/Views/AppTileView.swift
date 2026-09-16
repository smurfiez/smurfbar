import SwiftUI
import UniformTypeIdentifiers

/// An individual app tile in the taskbar.
/// Shows the app icon, name, active/running state, pin state, and handles click/drag-and-drop.
struct AppTileView: View {
    @ObservedObject var app: RunningApp
    @ObservedObject var prefs = PreferencesService.shared
    let isActive: Bool
    let onTap: () -> Void
    let onRightClick: () -> Void
    var onHover: ((Bool) -> Void)? = nil

    @State private var isHovered: Bool = false
    @State private var isDropTarget: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // App icon
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            // App name (optional)
            if prefs.showAppLabels {
                Text(app.localizedName)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(isActive ? .primary : (app.isRunning ? .secondary : .secondary.opacity(0.8)))
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
        .onHover { hovering in
            isHovered = hovering
            onHover?(hovering)
        }
        .onTapGesture {
            onTap()
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTarget) { providers in
            handleDrop(providers: providers)
        }
        .contextMenu {
            appContextMenu
        }
        .help(prefs.showWindowPreviews && app.isRunning && !app.windows.isEmpty ? "" : tooltipText)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var indicatorBar: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 1)
                .fill(prefs.accentColorChoice.color)
                .frame(height: 2)
                .padding(.horizontal, 8)
                .padding(prefs.taskbarPosition == .top ? .top : .bottom, 1)
        } else if app.isRunning {
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

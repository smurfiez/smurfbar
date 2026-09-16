import SwiftUI

/// An individual app tile in the taskbar.
/// Shows the app icon, name, and active/running state.
struct AppTileView: View {
    @ObservedObject var app: RunningApp
    let isActive: Bool
    let onTap: () -> Void
    let onRightClick: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            // App icon
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)

            // App name
            Text(app.localizedName)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 36)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            // Active indicator — bottom accent line
            VStack {
                Spacer()
                if isActive {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .padding(.horizontal, 8)
                } else {
                    // Running dot indicator
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .padding(.bottom, 1)
                }
            }
        )
        .opacity(app.isHidden ? 0.5 : 1.0)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            appContextMenu
        }
        .help(tooltipText)
    }

    // MARK: - Subviews

    private var tileBackground: some View {
        Group {
            if isActive {
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

        Divider()

        Button("Show in Finder") {
            AppActionService.shared.showInFinder(app)
        }

        Divider()

        Button("Quit \(app.localizedName)") {
            AppActionService.shared.quitApp(app)
        }

        Button("Force Quit") {
            AppActionService.shared.forceQuitApp(app)
        }
    }

    private var tooltipText: String {
        var tooltip = app.localizedName
        if app.isHidden {
            tooltip += " (Hidden)"
        }
        let windowCount = app.windows.count
        if windowCount > 0 {
            tooltip += " — \(windowCount) window\(windowCount == 1 ? "" : "s")"
        }
        return tooltip
    }
}

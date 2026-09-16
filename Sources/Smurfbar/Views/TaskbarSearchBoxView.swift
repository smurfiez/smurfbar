import SwiftUI

/// Embedded search widget in the taskbar for instant search access.
struct TaskbarSearchBoxView: View {
    @ObservedObject var prefs = PreferencesService.shared
    let screen: NSScreen
    let onOpenPreferences: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        if prefs.searchStyle != .hidden {
            Button(action: {
                AppLauncherWindowController.shared.toggle(relativeTo: screen, onOpenPreferences: onOpenPreferences)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    if prefs.searchStyle == .searchBox && !prefs.taskbarPosition.isVertical {
                        Text("Search")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.8))
                        Spacer()
                    }
                }
                .padding(.horizontal, (prefs.searchStyle == .searchBox && !prefs.taskbarPosition.isVertical) ? 8 : 6)
                .frame(
                    width: (prefs.searchStyle == .searchBox && !prefs.taskbarPosition.isVertical) ? (prefs.compactMode ? 90 : 110) : (prefs.compactMode ? 28 : 32),
                    height: prefs.compactMode ? 28 : 32
                )
                .background(isHovered ? Color.primary.opacity(0.1) : Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Search applications (Start Menu)")
            .onHover { isHovered = $0 }
        }
    }
}

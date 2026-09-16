import SwiftUI
import AppKit

/// Displays window thumbnails for a hovered app in a popover/overlay above the taskbar.
struct WindowPreviewView: View {
    let app: RunningApp
    let onWindowSelect: (AppWindow) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 16, height: 16)
                Text(app.localizedName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(app.windows.count) window\(app.windows.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            Divider()

            // Window thumbnails
            if app.windows.isEmpty {
                Text("No visible windows")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(app.windows) { window in
                            WindowThumbnailView(window: window) {
                                onWindowSelect(window)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(minWidth: 200, maxWidth: 500)
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
    }
}

/// A single window thumbnail with title.
struct WindowThumbnailView: View {
    let window: AppWindow
    let onSelect: () -> Void

    @State private var thumbnail: NSImage?
    @State private var isHovered: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 130)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 160, height: 100)
                        .overlay(
                            Image(systemName: "macwindow")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary.opacity(0.4))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            // Window title
            Text(window.title.isEmpty ? "Untitled" : window.title)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 160)
        }
        .padding(4)
        .background(isHovered ? Color.primary.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        // Load thumbnail on a background queue to avoid UI jank
        DispatchQueue.global(qos: .userInitiated).async {
            let image = WindowListService.shared.captureWindowThumbnail(
                windowID: window.windowID,
                maxSize: CGSize(width: 400, height: 260)
            )
            DispatchQueue.main.async {
                self.thumbnail = image
            }
        }
    }
}

/// NSVisualEffectView wrapper for SwiftUI.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

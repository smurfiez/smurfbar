import AppKit
import SwiftUI

/// Floating translucent preview overlay window indicating target snap area.
class SnapOverlayWindow: NSPanel {
    static let shared = SnapOverlayWindow()

    private init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.ignoresMouseEvents = true
        self.hasShadow = false
        self.isReleasedWhenClosed = false

        let hosting = NSHostingView(rootView: SnapOverlayContentView())
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
    }

    func show(in frame: CGRect) {
        self.setFrame(frame, display: true, animate: false)
        self.orderFront(nil)
    }

    func hide() {
        self.orderOut(nil)
    }
}

struct SnapOverlayContentView: View {
    @ObservedObject var prefs = PreferencesService.shared

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(prefs.accentColorChoice.color.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(prefs.accentColorChoice.color.opacity(0.7), lineWidth: 2)
            )
            .padding(4)
    }
}

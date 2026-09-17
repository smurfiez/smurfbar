import SwiftUI
import AppKit

/// A view that renders the official Smurfbar application icon with native macOS styling.
struct AppIconView: View {
    var size: CGFloat = 64
    var showShadow: Bool = true
    var cornerRadius: CGFloat? = nil

    private var effectiveCornerRadius: CGFloat {
        cornerRadius ?? (size * 0.223)
    }

    var body: some View {
        Group {
            if let image = AppIconProvider.shared.iconImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                fallbackIcon
            }
        }
        .shadow(color: showShadow ? Color.black.opacity(0.18) : .clear,
                radius: size * 0.08,
                x: 0,
                y: size * 0.04)
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: effectiveCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.45, blue: 0.95), Color(red: 0.04, green: 0.18, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: size * 0.45))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

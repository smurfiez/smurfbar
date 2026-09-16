import SwiftUI

/// Smurfbar — A Windows-style taskbar for macOS.
///
/// This is the main entry point. It uses @NSApplicationDelegateAdaptor
/// to bridge to AppKit for window management, since SwiftUI's window
/// APIs don't support the non-activating panel behavior needed.
@main
struct SmurfbarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a Settings scene as a placeholder.
        // The actual taskbar UI is managed by AppDelegate via TaskbarPanel.
        Settings {
            Text("Smurfbar Settings")
                .frame(width: 400, height: 300)
                .padding()
        }
    }
}

import AppKit
import SwiftUI

/// Custom NSHostingView that handles clicks immediately on first mouse down
/// without requiring prior window or application activation.
class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

import AppKit
import CoreGraphics
import Combine

/// Service to check and request macOS Screen Recording permission.
/// Required for capturing window thumbnails and retrieving window titles.
class ScreenCaptureService: ObservableObject {
    static let shared = ScreenCaptureService()

    @Published private(set) var isPermissionGranted: Bool = false

    private init() {
        checkPermission()
    }

    /// Check the current Screen Recording permission status.
    @discardableResult
    func checkPermission() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        if isPermissionGranted != granted {
            DispatchQueue.main.async {
                self.isPermissionGranted = granted
            }
        }
        return granted
    }

    /// Prompt the user for Screen Recording permission if not yet granted.
    func requestPermission() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
        checkPermission()
    }

    /// Open System Settings directly to Privacy & Security → Screen Recording.
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

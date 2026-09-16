import AppKit
import CoreGraphics

/// Enumerates windows on screen using CGWindowListCopyWindowInfo
/// and captures window thumbnails using CGWindowListCreateImage.
class WindowListService {
    static let shared = WindowListService()

    private init() {}

    /// Get all normal (layer 0) windows for a specific process.
    func getWindows(for pid: pid_t) -> [AppWindow] {
        return getAllWindows().filter { $0.ownerPID == pid }
    }

    /// Get all normal windows on screen, grouped by owning PID.
    func getAllWindows() -> [AppWindow] {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowInfoList.compactMap { AppWindow(from: $0) }
    }

    /// Get a dictionary mapping PIDs to their window lists.
    func getWindowsByPID() -> [pid_t: [AppWindow]] {
        var result: [pid_t: [AppWindow]] = [:]
        for window in getAllWindows() {
            result[window.ownerPID, default: []].append(window)
        }
        return result
    }

    /// Capture a thumbnail image of a specific window.
    /// Returns nil if the window doesn't exist or can't be captured.
    func captureWindowThumbnail(windowID: CGWindowID, maxSize: CGSize = CGSize(width: 300, height: 200)) -> NSImage? {
        // Capture the window image
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }

        let fullSize = CGSize(width: cgImage.width, height: cgImage.height)

        // Scale down to fit maxSize while preserving aspect ratio
        let scale: CGFloat
        if fullSize.width / fullSize.height > maxSize.width / maxSize.height {
            scale = maxSize.width / fullSize.width
        } else {
            scale = maxSize.height / fullSize.height
        }
        let thumbSize = NSSize(
            width: fullSize.width * scale,
            height: fullSize.height * scale
        )

        let image = NSImage(cgImage: cgImage, size: thumbSize)
        return image
    }
}

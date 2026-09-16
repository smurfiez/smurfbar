import Foundation
import SwiftUI
import Combine
import ServiceManagement

/// Available theme modes for the taskbar
enum ThemeMode: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"

    var id: String { rawValue }

    var appearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .light:
            return NSAppearance(named: .aqua)
        }
    }

    var visualEffectMaterial: NSVisualEffectView.Material {
        return .menu
    }
}

/// Service managing user settings and preferences.
class PreferencesService: ObservableObject {
    static let shared = PreferencesService()

    private let defaults = UserDefaults.standard

    // Keys
    private let keyAutoHide = "Smurfbar_AutoHide"
    private let keyTheme = "Smurfbar_Theme"
    private let keyShowPreviews = "Smurfbar_ShowPreviews"
    private let keyCompactMode = "Smurfbar_CompactMode"
    private let keyShowAppLabels = "Smurfbar_ShowAppLabels"

    @Published var autoHide: Bool {
        didSet { defaults.set(autoHide, forKey: keyAutoHide) }
    }

    @Published var theme: ThemeMode {
        didSet { defaults.set(theme.rawValue, forKey: keyTheme) }
    }

    @Published var showWindowPreviews: Bool {
        didSet { defaults.set(showWindowPreviews, forKey: keyShowPreviews) }
    }

    @Published var compactMode: Bool {
        didSet { defaults.set(compactMode, forKey: keyCompactMode) }
    }

    @Published var showAppLabels: Bool {
        didSet { defaults.set(showAppLabels, forKey: keyShowAppLabels) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }

    var taskbarHeight: CGFloat {
        compactMode ? 40 : 48
    }

    private init() {
        self.autoHide = defaults.bool(forKey: keyAutoHide)
        let themeRaw = defaults.string(forKey: keyTheme) ?? ThemeMode.system.rawValue
        self.theme = ThemeMode(rawValue: themeRaw) ?? .system
        self.showWindowPreviews = defaults.object(forKey: keyShowPreviews) == nil ? true : defaults.bool(forKey: keyShowPreviews)
        self.compactMode = defaults.bool(forKey: keyCompactMode)
        self.showAppLabels = defaults.object(forKey: keyShowAppLabels) == nil ? true : defaults.bool(forKey: keyShowAppLabels)

        if #available(macOS 13.0, *) {
            self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        } else {
            self.launchAtLogin = false
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("⚠️ Failed to update launchAtLogin status: \(error)")
            }
        }
    }
}

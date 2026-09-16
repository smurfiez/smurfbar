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

/// Available taskbar screen edge positions
enum TaskbarPosition: String, CaseIterable, Identifiable, Codable {
    case bottom = "Bottom"
    case top = "Top"
    case left = "Left"
    case right = "Right"

    var id: String { rawValue }

    var isVertical: Bool {
        self == .left || self == .right
    }
}

/// Window grouping modes
enum WindowGroupingMode: String, CaseIterable, Identifiable, Codable {
    case alwaysCombine = "Always Combine"
    case neverCombine = "Never Combine"
    case combineWhenFull = "Combine When Full"

    var id: String { rawValue }
}

/// Taskbar search presentation styles
enum TaskbarSearchStyle: String, CaseIterable, Identifiable, Codable {
    case searchBox = "Search Box"
    case iconOnly = "Icon Only"
    case hidden = "Hidden"

    var id: String { rawValue }
}

/// Available taskbar item alignments
enum TaskbarAlignment: String, CaseIterable, Identifiable, Codable {
    case left = "Left"
    case center = "Center"

    var id: String { rawValue }
}

/// Accent color options for the taskbar
enum AccentColorOption: String, CaseIterable, Identifiable, Codable {
    case system = "System"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"
    case orange = "Orange"
    case green = "Green"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .system: return .accentColor
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        }
    }
}

/// Multi-monitor taskbar display mode
enum MultiMonitorMode: String, CaseIterable, Identifiable, Codable {
    case allMonitors = "All Monitors"
    case primaryOnly = "Primary Only"

    var id: String { rawValue }
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
    private let keyTaskbarPosition = "Smurfbar_TaskbarPosition"
    private let keyTaskbarAlignment = "Smurfbar_TaskbarAlignment"
    private let keyTaskbarOpacity = "Smurfbar_TaskbarOpacity"
    private let keyAccentColor = "Smurfbar_AccentColor"
    private let keyEnableWindowSnapping = "Smurfbar_EnableWindowSnapping"
    private let keyMultiMonitorMode = "Smurfbar_MultiMonitorMode"
    private let keyShowOverflowArrows = "Smurfbar_ShowOverflowArrows"
    private let keyWindowGroupingMode = "Smurfbar_WindowGroupingMode"
    private let keySearchStyle = "Smurfbar_SearchStyle"
    private let keyShowSystemGlance = "Smurfbar_ShowSystemGlance"
    private let keyAutoCheckUpdates = "Smurfbar_AutoCheckUpdates"

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

    @Published var taskbarPosition: TaskbarPosition {
        didSet { defaults.set(taskbarPosition.rawValue, forKey: keyTaskbarPosition) }
    }

    @Published var taskbarAlignment: TaskbarAlignment {
        didSet { defaults.set(taskbarAlignment.rawValue, forKey: keyTaskbarAlignment) }
    }

    @Published var taskbarOpacity: Double {
        didSet { defaults.set(taskbarOpacity, forKey: keyTaskbarOpacity) }
    }

    @Published var accentColorChoice: AccentColorOption {
        didSet { defaults.set(accentColorChoice.rawValue, forKey: keyAccentColor) }
    }

    @Published var enableWindowSnapping: Bool {
        didSet { defaults.set(enableWindowSnapping, forKey: keyEnableWindowSnapping) }
    }

    @Published var multiMonitorMode: MultiMonitorMode {
        didSet { defaults.set(multiMonitorMode.rawValue, forKey: keyMultiMonitorMode) }
    }

    @Published var showOverflowArrows: Bool {
        didSet { defaults.set(showOverflowArrows, forKey: keyShowOverflowArrows) }
    }

    @Published var windowGroupingMode: WindowGroupingMode {
        didSet { defaults.set(windowGroupingMode.rawValue, forKey: keyWindowGroupingMode) }
    }

    @Published var searchStyle: TaskbarSearchStyle {
        didSet { defaults.set(searchStyle.rawValue, forKey: keySearchStyle) }
    }

    @Published var showSystemGlance: Bool {
        didSet { defaults.set(showSystemGlance, forKey: keyShowSystemGlance) }
    }

    @Published var autoCheckUpdates: Bool {
        didSet { defaults.set(autoCheckUpdates, forKey: keyAutoCheckUpdates) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            setLaunchAtLogin(launchAtLogin)
        }
    }

    var taskbarHeight: CGFloat {
        compactMode ? 40 : 48
    }

    var taskbarThickness: CGFloat {
        taskbarPosition.isVertical ? (compactMode ? 46 : 54) : (compactMode ? 40 : 48)
    }

    private init() {
        self.autoHide = defaults.bool(forKey: keyAutoHide)
        let themeRaw = defaults.string(forKey: keyTheme) ?? ThemeMode.system.rawValue
        self.theme = ThemeMode(rawValue: themeRaw) ?? .system
        self.showWindowPreviews = defaults.object(forKey: keyShowPreviews) == nil ? true : defaults.bool(forKey: keyShowPreviews)
        self.compactMode = defaults.bool(forKey: keyCompactMode)
        self.showAppLabels = defaults.object(forKey: keyShowAppLabels) == nil ? true : defaults.bool(forKey: keyShowAppLabels)

        let posRaw = defaults.string(forKey: keyTaskbarPosition) ?? TaskbarPosition.bottom.rawValue
        self.taskbarPosition = TaskbarPosition(rawValue: posRaw) ?? .bottom

        let alignRaw = defaults.string(forKey: keyTaskbarAlignment) ?? TaskbarAlignment.left.rawValue
        self.taskbarAlignment = TaskbarAlignment(rawValue: alignRaw) ?? .left

        self.taskbarOpacity = defaults.object(forKey: keyTaskbarOpacity) == nil ? 1.0 : defaults.double(forKey: keyTaskbarOpacity)

        let accentRaw = defaults.string(forKey: keyAccentColor) ?? AccentColorOption.system.rawValue
        self.accentColorChoice = AccentColorOption(rawValue: accentRaw) ?? .system

        self.enableWindowSnapping = defaults.object(forKey: keyEnableWindowSnapping) == nil ? true : defaults.bool(forKey: keyEnableWindowSnapping)

        let monitorRaw = defaults.string(forKey: keyMultiMonitorMode) ?? MultiMonitorMode.allMonitors.rawValue
        self.multiMonitorMode = MultiMonitorMode(rawValue: monitorRaw) ?? .allMonitors

        self.showOverflowArrows = defaults.object(forKey: keyShowOverflowArrows) == nil ? true : defaults.bool(forKey: keyShowOverflowArrows)

        let groupRaw = defaults.string(forKey: keyWindowGroupingMode) ?? WindowGroupingMode.alwaysCombine.rawValue
        self.windowGroupingMode = WindowGroupingMode(rawValue: groupRaw) ?? .alwaysCombine

        let searchRaw = defaults.string(forKey: keySearchStyle) ?? TaskbarSearchStyle.searchBox.rawValue
        self.searchStyle = TaskbarSearchStyle(rawValue: searchRaw) ?? .searchBox

        self.showSystemGlance = defaults.object(forKey: keyShowSystemGlance) == nil ? true : defaults.bool(forKey: keyShowSystemGlance)

        self.autoCheckUpdates = defaults.object(forKey: keyAutoCheckUpdates) == nil ? true : defaults.bool(forKey: keyAutoCheckUpdates)

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

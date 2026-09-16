# Smurfbar 🪟

A sleek, lightweight Windows-style taskbar for macOS built with **Swift** and **SwiftUI**.

Smurfbar brings a bottom-docked, classic taskbar experience to macOS with native system vibrancy, running and pinned application tiles, a Start Menu app launcher, live hover window previews, interactive calendar flyout, and seamless app switching.

---

## ✨ Features

- **Bottom Taskbar**: Clean, non-activating panel docked to the bottom of the screen with native macOS translucent blur (`NSVisualEffectView`).
- **Start Menu (App Launcher)**:
  - Open via the Smurfbar menu button (`square.grid.2x2`).
  - Real-time search across all installed applications (`/Applications`, `/System/Applications`, `~/Applications`).
  - Quick power actions: Lock Screen, Sleep, Restart, Shut Down, and Settings shortcut.
  - Full keyboard navigation (`Return` to launch first match, `Escape` to close).
- **App Pinning**:
  - Keep favorite apps permanently docked even when not running.
  - Seamlessly launches non-running apps on click.
  - Pin or unpin apps directly from the right-click context menu or Settings.
- **Running App Tiles**:
  - Real-time tracking of active and background applications.
  - Running indicator dots and active app accent bars.
  - Window count badges for multi-window applications.
  - One-click window activation and toggle minimize/restore.
- **Drag & Drop File Opening & Taskbar Reordering**:
  - Drag files directly from Finder onto app tiles to open them with that application.
  - Drag and drop app and window tiles directly along the taskbar to arrange workflows and reorder pinned/running apps.
- **Windows 11 Snap Layouts Bar**:
  - Drag any window towards the top of the screen to reveal the floating Snap Layouts bar.
  - Choose between 6 workflow templates (50/50 split, 67/33 priority focus, 3 columns, focus + stack, and 4-quadrant grid) to instantly tile and arrange multi-window workflows.
- **Live Window Previews**: Hover over any running app tile to view live window thumbnails and click to switch directly to a specific window.
- **Interactive Calendar & Clock**:
  - Built-in digital clock updating live every second.
  - Click to open an interactive calendar flyout with month grid navigation and today highlighting.
- **Taskbar Auto-Hide**:
  - Automatically slides down when the mouse moves away.
  - Smoothly reveals when the mouse approaches the bottom screen edge.
- **Preferences & Settings Window**:
  - Toggle Auto-hide, Compact Taskbar Height (40px vs 48px), App Name Labels, and Window Previews.
  - Choose between System, Dark, and Light appearance themes.
  - Manage and unpin applications.
- **macOS Dock Integration**: Automatically auto-hides the default macOS Dock while running and safely restores it upon exit.
- **Menu Bar Status Item**: Control Smurfbar from the macOS menu bar — toggle visibility, open Preferences (`Cmd+,`), restore the Dock, or quit.
- **Spaces & Fullscreen Support**: Visible across all macOS Spaces and alongside fullscreen auxiliary windows.

---

## 📋 Requirements

- **macOS**: macOS 14.0 (Sonoma) or later
- **Swift**: Swift 6.0 toolchain (uses Swift 5 language mode)
- **Permissions**:
  - **Accessibility** (`System Settings → Privacy & Security → Accessibility`): Required to monitor windows, switch between apps, and inspect application state.
  - **Screen Recording** (optional/prompted): Required for rendering live window thumbnail previews.

---

## 🚀 Getting Started

### Clone the Repository

```bash
git clone https://github.com/smurfiez/smurfbar.git
cd smurfbar
```

### Build & Package (.app)

A build script is included to compile the release binary and bundle it into `Smurfbar.app`:

```bash
chmod +x Scripts/build.sh
./Scripts/build.sh
```

The compiled application bundle will be created at `.build/Smurfbar.app`.

### Run

```bash
# Launch directly
open .build/Smurfbar.app

# Or install to your Applications folder
cp -R .build/Smurfbar.app /Applications/
```

### Development with Swift PM

You can also build directly using Swift Package Manager:

```bash
swift build
```

---

## ⌨️ Shortcuts & Controls

| Action | Control / Shortcut |
| :--- | :--- |
| **Open Start Menu** | Click Smurfbar button (bottom-left) |
| **Search Apps** | Type immediately in Start Menu |
| **Launch Top Search Result** | `Return` in Start Menu |
| **Dismiss Flyouts** | `Escape` or click anywhere outside |
| **Activate / Minimize App** | Left-click app tile |
| **Window Previews** | Hover mouse over app tile |
| **Switch to Specific Window** | Click thumbnail inside hover preview |
| **Open File with App** | Drag & drop file onto app tile |
| **Reorder Taskbar Tiles** | Drag & drop app tile to new position on taskbar |
| **Snap Layouts Drop Bar** | Drag window to top center of screen |
| **Pin / Unpin App** | Right-click app tile → **Pin / Unpin from Taskbar** |
| **App Management Menu** | Right-click app tile |
| **Open Calendar** | Click clock (bottom-right) |
| **Open Preferences** | Menu Bar icon → **Preferences...** (`Cmd + ,`) or Start Menu gear icon |
| **Toggle Taskbar Visibility** | Menu Bar icon → **Toggle Taskbar** (`Cmd + Shift + T`) |
| **Restore Default Dock** | Menu Bar icon → **Restore Dock** |
| **Quit Smurfbar** | Menu Bar icon → **Quit Smurfbar** (`Cmd + Q`) |

---

## 🛠 Project Structure

```
Smurfbar/
├── Package.swift               # SPM package manifest
├── Resources/
│   └── Info.plist              # Bundle metadata & permissions usage descriptions
├── Scripts/
│   └── build.sh                # Release build & .app packager script
└── Sources/
    └── Smurfbar/
        ├── AppDelegate.swift   # Lifecycle & coordination
        ├── SmurfbarApp.swift   # NSApplication entry point
        ├── Controllers/
        │   ├── AppLauncherWindowController.swift  # Start Menu popup panel
        │   ├── CalendarWindowController.swift     # Calendar flyout panel
        │   ├── PreferencesWindowController.swift  # Settings window controller
        │   └── StatusBarController.swift          # Menu bar status item
        ├── Models/
        │   ├── AppWindow.swift               # Window model representation
        │   ├── PinnedApp.swift               # Pinned application model
        │   └── RunningApp.swift              # Running & pinned application model
        ├── Services/
        │   ├── AccessibilityService.swift    # Accessibility permission check & prompts
        │   ├── AppActionService.swift        # App activation, launch & file opening
        │   ├── AppDiscoveryService.swift     # System application indexing & search
        │   ├── AppMonitor.swift              # App launch/terminate & pin state tracking
        │   ├── DockService.swift             # macOS Dock auto-hide control
        │   ├── PinnedAppsService.swift       # UserDefaults pinned apps persistence
        │   ├── PreferencesService.swift      # User settings & appearance store
        │   └── WindowListService.swift       # CGWindowList queries & thumbnail capture
        ├── Views/
        │   ├── AppLauncherFlyoutView.swift   # Start Menu search & app grid
        │   ├── AppTileView.swift             # App icon, name, indicator, drag-and-drop
        │   ├── CalendarFlyoutView.swift      # Interactive month grid & digital clock
        │   ├── PreferencesView.swift         # Multi-tab settings interface
        │   ├── TaskbarContentView.swift      # Main horizontal taskbar view
        │   └── WindowPreviewView.swift       # Popover window thumbnails
        └── Window/
            ├── TaskbarPanel.swift            # Borderless floating NSPanel with auto-hide
            └── TaskbarWindowController.swift # Screen management & frame tracking
```

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

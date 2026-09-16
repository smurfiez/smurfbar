# Smurfbar 🪟

A sleek, lightweight Windows-style taskbar for macOS built with **Swift** and **SwiftUI**.

Smurfbar brings a bottom-docked, classic taskbar experience to macOS with native system vibrancy, running application tiles, live hover window previews, and seamless app switching.

---

## ✨ Features

- **Bottom Taskbar**: Clean, non-activating panel docked to the bottom of the screen with native macOS translucent blur (`NSVisualEffectView`).
- **Running App Tiles**:
  - Real-time tracking of active and background applications.
  - Running indicator dots and active app accent bars.
  - Window count badges for multi-window applications.
  - One-click window activation and toggle minimize/restore.
- **Live Window Previews**: Hover over any running app tile to view live window thumbnails and click to switch directly to a specific window.
- **App Context Menu**: Right-click any app tile for instant actions: *Show All Windows*, *Hide/Unhide*, *Show in Finder*, *Quit*, or *Force Quit*.
- **macOS Dock Integration**: Automatically auto-hides the default macOS Dock while running and safely restores it upon exit.
- **Menu Bar Status Item**: Control Smurfbar from the macOS menu bar — toggle visibility, restore the Dock, or quit the application.
- **Spaces & Fullscreen Support**: Visible across all macOS Spaces and alongside fullscreen auxiliary windows.
- **System Tray Clock**: Built-in clock with full date tooltip display.

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
| **Activate / Minimize App** | Left-click app tile |
| **Window Previews** | Hover mouse over app tile |
| **Switch to Specific Window** | Click thumbnail inside hover preview |
| **App Management Menu** | Right-click app tile |
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
        │   └── StatusBarController.swift     # Menu bar status item
        ├── Models/
        │   ├── AppWindow.swift               # Window model representation
        │   └── RunningApp.swift              # Observable running application model
        ├── Services/
        │   ├── AccessibilityService.swift    # Accessibility permission check & prompts
        │   ├── AppActionService.swift        # App & window activation/switching actions
        │   ├── AppMonitor.swift              # App launch/terminate/switch monitoring
        │   ├── DockService.swift             # macOS Dock auto-hide control
        │   └── WindowListService.swift       # CGWindowList queries & thumbnail capture
        ├── Views/
        │   ├── AppTileView.swift             # App icon, name, indicator, context menu
        │   ├── TaskbarContentView.swift      # Main horizontal taskbar view
        │   └── WindowPreviewView.swift       # Popover window thumbnails
        └── Window/
            ├── TaskbarPanel.swift            # Custom borderless floating NSPanel
            └── TaskbarWindowController.swift # Screen management & frame tracking
```

---

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

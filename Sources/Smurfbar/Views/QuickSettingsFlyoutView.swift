import SwiftUI
import AppKit

/// Windows 11 / macOS Control Center style Quick Settings flyout.
struct QuickSettingsFlyoutView: View {
    @ObservedObject var systemStatus = SystemStatusService.shared
    let onClose: () -> Void
    let onOpenPreferences: () -> Void

    @State private var isDNDActive: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            // Quick Toggles Grid
            quickTogglesSection

            // Sliders Section (Volume & Brightness)
            slidersSection

            // Media Controls (if active or available)
            if systemStatus.media.isAvailable {
                mediaPlaybackSection
            }

            Divider()

            // Footer (Battery info & Settings shortcut)
            footerSection
        }
        .padding(14)
        .frame(width: 320)
        .background(VisualEffectBlur(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 16, y: -6)
    }

    // MARK: - Quick Toggles

    private var quickTogglesSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            // Wi-Fi
            toggleButton(
                title: "Wi-Fi",
                subtitle: systemStatus.wifi.isConnected ? systemStatus.wifi.ssid : "Off",
                icon: systemStatus.wifi.iconName,
                isActive: systemStatus.wifi.isConnected
            ) {
                openNetworkPreferences()
            }

            // Bluetooth
            toggleButton(
                title: "Bluetooth",
                subtitle: "On",
                icon: "wave.3.left",
                isActive: true
            ) {
                openBluetoothPreferences()
            }

            // Focus / Do Not Disturb
            toggleButton(
                title: "Do Not Disturb",
                subtitle: isDNDActive ? "On" : "Off",
                icon: isDNDActive ? "moon.fill" : "moon",
                isActive: isDNDActive
            ) {
                isDNDActive.toggle()
            }

            // Lock Screen
            toggleButton(
                title: "Lock Screen",
                subtitle: "Instant",
                icon: "lock.fill",
                isActive: false
            ) {
                lockScreen()
                onClose()
            }
        }
    }

    private func toggleButton(
        title: String,
        subtitle: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isActive ? .white : .primary)
                    .frame(width: 28, height: 28)
                    .background(isActive ? Color.accentColor : Color.primary.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sliders (Volume & Brightness)

    private var slidersSection: some View {
        VStack(spacing: 10) {
            // Volume Slider
            HStack(spacing: 10) {
                Button(action: {
                    systemStatus.toggleMute()
                }) {
                    Image(systemName: volumeIconName)
                        .font(.system(size: 14))
                        .foregroundColor(systemStatus.isMuted ? .secondary : .accentColor)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)

                Slider(
                    value: Binding(
                        get: { Double(systemStatus.volume) },
                        set: { systemStatus.setVolume(Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .accentColor(.accentColor)

                Text("\(Int(systemStatus.volume * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }

            // Brightness Slider
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                Slider(
                    value: Binding(
                        get: { Double(systemStatus.brightness) },
                        set: { systemStatus.setBrightness(Float($0)) }
                    ),
                    in: 0.0...1.0
                )
                .accentColor(.accentColor)

                Text("\(Int(systemStatus.brightness * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    private var volumeIconName: String {
        if systemStatus.isMuted || systemStatus.volume == 0 {
            return "speaker.slash.fill"
        } else if systemStatus.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if systemStatus.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    // MARK: - Media Playback Section

    private var mediaPlaybackSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(systemStatus.media.trackTitle.isEmpty ? "Now Playing" : systemStatus.media.trackTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Text(systemStatus.media.artistName.isEmpty ? systemStatus.media.appName : systemStatus.media.artistName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Playback controls
            HStack(spacing: 8) {
                Button(action: { systemStatus.previousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Button(action: { systemStatus.togglePlayPause() }) {
                    Image(systemName: systemStatus.media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Button(action: { systemStatus.nextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack {
            // Battery Status text
            HStack(spacing: 5) {
                Image(systemName: systemStatus.battery.iconName)
                    .font(.system(size: 13))
                    .foregroundColor(systemStatus.battery.percentage < 20 ? .red : .primary)

                if systemStatus.battery.hasBattery {
                    Text("\(systemStatus.battery.percentage)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primary)

                    Text(systemStatus.battery.isCharging ? "• Charging" : (systemStatus.battery.isPluggedIn ? "• Power Adapter" : ""))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("Power Adapter")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Settings Shortcut Button
            Button(action: {
                onClose()
                onOpenPreferences()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(4)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Smurfbar Preferences")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - System Actions

    private func openNetworkPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openBluetoothPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preferences.Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }

    private func lockScreen() {
        let script = "tell application \"System Events\" to key code 12 using {control down, command down}"
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
}

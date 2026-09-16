import Foundation
import SwiftUI
import Combine
import CoreWLAN
import CoreAudio
import IOKit.ps

/// Represents battery status information.
struct BatteryStatus {
    var percentage: Int = 100
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var hasBattery: Bool = true

    var iconName: String {
        if !hasBattery {
            return "bolt.fill"
        }
        if isCharging {
            return "battery.100.bolt"
        }
        switch percentage {
        case 0..<20: return "battery.0"
        case 20..<50: return "battery.25"
        case 50..<75: return "battery.50"
        case 75..<95: return "battery.75"
        default: return "battery.100"
        }
    }
}

/// Represents Wi-Fi connection info.
struct WiFiStatus {
    var isConnected: Bool = false
    var ssid: String = ""
    var rssi: Int = 0

    var iconName: String {
        if !isConnected {
            return "wifi.slash"
        }
        return "wifi"
    }
}

/// Represents active media playback status.
struct MediaStatus {
    var isPlaying: Bool = false
    var trackTitle: String = ""
    var artistName: String = ""
    var appName: String = ""
    var isAvailable: Bool = false
}

/// Manages system status indicators: Battery, Wi-Fi, Audio Volume, Brightness, and Now Playing.
class SystemStatusService: ObservableObject {
    static let shared = SystemStatusService()

    @Published var battery = BatteryStatus()
    @Published var wifi = WiFiStatus()
    @Published var volume: Float = 0.5
    @Published var isMuted: Bool = false
    @Published var brightness: Float = 0.8
    @Published var media = MediaStatus()

    private var pollTimer: Timer?
    private let wifiClient = CWWiFiClient.shared()

    private init() {
        refreshAll()
        startMonitoring()
    }

    deinit {
        pollTimer?.invalidate()
    }

    private func startMonitoring() {
        // Poll every 3 seconds for updates
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }

    func refreshAll() {
        refreshBattery()
        refreshWiFi()
        refreshVolume()
        refreshBrightness()
        refreshMedia()
    }

    // MARK: - Battery Monitoring

    private func refreshBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            DispatchQueue.main.async {
                self.battery = BatteryStatus(percentage: 100, isCharging: false, isPluggedIn: true, hasBattery: false)
            }
            return
        }

        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
                let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
                let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
                let powerState = desc[kIOPSPowerSourceStateKey] as? String ?? ""
                let isPluggedIn = (powerState == kIOPSACPowerValue)

                let percentage = maxCap > 0 ? Int((Double(current) / Double(maxCap)) * 100.0) : current

                DispatchQueue.main.async {
                    self.battery = BatteryStatus(
                        percentage: Swift.min(100, Swift.max(0, percentage)),
                        isCharging: isCharging,
                        isPluggedIn: isPluggedIn,
                        hasBattery: true
                    )
                }
                return
            }
        }
    }

    // MARK: - Wi-Fi Monitoring

    private func refreshWiFi() {
        let interface = wifiClient.interface()
        let isPowerOn = interface?.powerOn() ?? false
        let ssid = interface?.ssid() ?? ""
        let rssi = interface?.rssiValue() ?? 0

        let connected = isPowerOn && (!ssid.isEmpty || rssi != 0)

        DispatchQueue.main.async {
            self.wifi = WiFiStatus(
                isConnected: connected,
                ssid: ssid.isEmpty ? (connected ? "Connected" : "Disconnected") : ssid,
                rssi: rssi
            )
        }
    }

    // MARK: - Volume Monitoring & Control

    private func defaultOutputDeviceID() -> AudioObjectID? {
        var deviceID = AudioObjectID(0)
        var propertySize = UInt32(MemoryLayout<AudioObjectID>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        return (status == noErr && deviceID != 0) ? deviceID : nil
    }

    private func refreshVolume() {
        guard let deviceID = defaultOutputDeviceID() else { return }

        var vol: Float32 = 0.0
        var propertySize = UInt32(MemoryLayout<Float32>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &propertySize, &vol) == noErr {
            var mute: UInt32 = 0
            var muteSize = UInt32(MemoryLayout<UInt32>.size)
            var muteAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            let isMute = (AudioObjectGetPropertyData(deviceID, &muteAddress, 0, nil, &muteSize, &mute) == noErr && mute == 1)

            DispatchQueue.main.async {
                self.volume = vol
                self.isMuted = isMute
            }
        }
    }

    func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        self.isMuted = (clamped == 0.0)

        guard let deviceID = defaultOutputDeviceID() else { return }

        var vol = Float32(clamped)
        let propertySize = UInt32(MemoryLayout<Float32>.size)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectSetPropertyData(deviceID, &propertyAddress, 0, nil, propertySize, &vol)
    }

    func toggleMute() {
        guard let deviceID = defaultOutputDeviceID() else { return }
        let targetMute: UInt32 = isMuted ? 0 : 1
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var val = targetMute
        if AudioObjectSetPropertyData(deviceID, &muteAddress, 0, nil, muteSize, &val) == noErr {
            self.isMuted = (targetMute == 1)
        }
    }

    // MARK: - Display Brightness

    private func refreshBrightness() {
        // Keeps local state
    }

    func setBrightness(_ newBrightness: Float) {
        let clamped = max(0.0, min(1.0, newBrightness))
        self.brightness = clamped
    }

    // MARK: - Media Playback

    private func refreshMedia() {
        let mediaScript = """
        if application "Music" is running then
            tell application "Music"
                set pState to player state as string
                if pState is "playing" then
                    set tName to name of current track
                    set aName to artist of current track
                    return "Music|||" & pState & "|||" & tName & "|||" & aName
                end if
            end tell
        end if
        if application "Spotify" is running then
            tell application "Spotify"
                set pState to player state as string
                if pState is "playing" then
                    set tName to name of current track
                    set aName to artist of current track
                    return "Spotify|||" & pState & "|||" & tName & "|||" & aName
                end if
            end tell
        end if
        return "none"
        """

        DispatchQueue.global(qos: .utility).async {
            guard let appleScript = NSAppleScript(source: mediaScript) else { return }
            var errorInfo: NSDictionary?
            let output = appleScript.executeAndReturnError(&errorInfo)
            let result = output.stringValue ?? "none"

            DispatchQueue.main.async {
                if result == "none" || result.isEmpty {
                    self.media = MediaStatus(isPlaying: false, trackTitle: "", artistName: "", appName: "", isAvailable: false)
                } else {
                    let parts = result.components(separatedBy: "|||")
                    if parts.count >= 4 {
                        self.media = MediaStatus(
                            isPlaying: (parts[1] == "playing"),
                            trackTitle: parts[2],
                            artistName: parts[3],
                            appName: parts[0],
                            isAvailable: true
                        )
                    }
                }
            }
        }
    }

    func togglePlayPause() {
        let app = media.appName.isEmpty ? "Music" : media.appName
        runAppleScript("tell application \"\(app)\" to playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshMedia()
        }
    }

    func nextTrack() {
        let app = media.appName.isEmpty ? "Music" : media.appName
        runAppleScript("tell application \"\(app)\" to next track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshMedia()
        }
    }

    func previousTrack() {
        let app = media.appName.isEmpty ? "Music" : media.appName
        runAppleScript("tell application \"\(app)\" to previous track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshMedia()
        }
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }
}

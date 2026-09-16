import SwiftUI
import Foundation
import Darwin

/// Mini system telemetry glance meter displayed in the taskbar system tray.
struct SystemGlanceWidget: View {
    @ObservedObject var prefs = PreferencesService.shared
    @State private var cpuPercent: Double = 8.0
    @State private var memoryPercent: Double = 45.0
    @State private var timer: Timer?
    @State private var previousCPULoad = host_cpu_load_info()

    var body: some View {
        if prefs.showSystemGlance {
            Button(action: {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                HStack(spacing: 4) {
                    // CPU meter
                    HStack(spacing: 2) {
                        Text("C")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(Int(cpuPercent))%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(cpuPercent > 80 ? .red : .primary)
                    }

                    // RAM meter
                    HStack(spacing: 2) {
                        Text("M")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("\(Int(memoryPercent))%")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(memoryPercent > 85 ? .orange : .primary)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("System Glance: \(Int(cpuPercent))% CPU, \(Int(memoryPercent))% RAM (Click to open Activity Monitor)")
            .onAppear {
                startMonitoring()
            }
            .onDisappear {
                stopMonitoring()
            }
        }
    }

    private func startMonitoring() {
        refreshStats()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            refreshStats()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func refreshStats() {
        // Sample host CPU
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let userDiff = Double(loadInfo.cpu_ticks.0 - previousCPULoad.cpu_ticks.0)
            let sysDiff = Double(loadInfo.cpu_ticks.1 - previousCPULoad.cpu_ticks.1)
            let idleDiff = Double(loadInfo.cpu_ticks.2 - previousCPULoad.cpu_ticks.2)
            let niceDiff = Double(loadInfo.cpu_ticks.3 - previousCPULoad.cpu_ticks.3)
            let total = userDiff + sysDiff + idleDiff + niceDiff

            if total > 0 {
                let usage = ((userDiff + sysDiff + niceDiff) / total) * 100.0
                self.cpuPercent = min(100.0, max(0.0, usage))
            }
            self.previousCPULoad = loadInfo
        }

        // Sample host Memory
        var stats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let vmErr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(vmCount)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &vmCount)
            }
        }

        if vmErr == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let used = active + wired + compressed
            let total = ProcessInfo.processInfo.physicalMemory

            if total > 0 {
                self.memoryPercent = min(100.0, max(0.0, (Double(used) / Double(total)) * 100.0))
            }
        }
    }
}

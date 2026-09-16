import Foundation
import Darwin

/// Snapshot of an application's CPU and memory resource usage.
struct ProcessPerformanceMetrics {
    let cpuPercentage: Double
    let memoryBytes: UInt64
    let memoryString: String
}

/// Service that monitors CPU and RAM performance telemetry for running application processes.
class AppPerformanceService {
    static let shared = AppPerformanceService()

    private var previousCPUTimes: [pid_t: (time: UInt64, timestamp: Date)] = [:]

    private init() {}

    /// Get current CPU and memory metrics for a given process ID
    func getMetrics(for pid: pid_t) -> ProcessPerformanceMetrics? {
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, size)

        guard result == size else { return nil }

        let memoryBytes = taskInfo.pti_resident_size
        let memoryString = formatBytes(memoryBytes)

        let totalCPUTime = taskInfo.pti_total_user + taskInfo.pti_total_system
        let now = Date()

        var cpuPercent: Double = 0.0
        if let previous = previousCPUTimes[pid] {
            let timeDelta = Double(now.timeIntervalSince(previous.timestamp))
            if timeDelta > 0.1 {
                let cpuDelta = Double(totalCPUTime - previous.time) / 1_000_000_000.0 // nanoseconds to seconds
                cpuPercent = min(999.0, max(0.0, (cpuDelta / timeDelta) * 100.0))
            }
        }
        previousCPUTimes[pid] = (time: totalCPUTime, timestamp: now)

        return ProcessPerformanceMetrics(
            cpuPercentage: cpuPercent,
            memoryBytes: memoryBytes,
            memoryString: memoryString
        )
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1024.0 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

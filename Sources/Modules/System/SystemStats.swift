import Foundation

// MARK: — Battery

/// Snapshot of battery state, sourced from IOKit power sources (event-driven).
public struct BatteryStats {
    /// Current charge level in percent (0–100). Nil when no battery is present.
    public var percentage: Int?
    /// Whether the adapter is connected.
    public var isCharging: Bool
    /// Charge cycle count reported by the hardware.
    public var cycleCount: Int?

    public static let unavailable = BatteryStats(percentage: nil, isCharging: false, cycleCount: nil)
}

// MARK: — CPU

/// CPU load snapshot (0.0 … 1.0 per core, averaged).
public struct CPUStats {
    /// Overall CPU usage across all cores (0.0 to 1.0).
    public var usage: Double
    /// History ring-buffer for sparkline (up to 30 samples).
    public var history: [Double]

    public static let zero = CPUStats(usage: 0, history: [])
}

// MARK: — RAM

/// Physical memory usage snapshot.
public struct RAMStats {
    /// Used bytes.
    public var used: UInt64
    /// Total physical memory bytes.
    public var total: UInt64

    public var usedGB: Double { Double(used) / 1_073_741_824 }
    public var totalGB: Double { Double(total) / 1_073_741_824 }
    public var usageFraction: Double {
        guard total > 0 else { return 0 }
        return Double(used) / Double(total)
    }

    public static let zero = RAMStats(used: 0, total: ProcessInfo.processInfo.physicalMemory)
}

// MARK: — Network

/// Network I/O rates for the primary interface.
public struct NetworkStats {
    /// Bytes received per second.
    public var bytesInPerSec: Double
    /// Bytes sent per second.
    public var bytesOutPerSec: Double

    public static let zero = NetworkStats(bytesInPerSec: 0, bytesOutPerSec: 0)

    /// Human-readable download rate string.
    public var downloadLabel: String { formatRate(bytesInPerSec) }
    /// Human-readable upload rate string.
    public var uploadLabel: String   { formatRate(bytesOutPerSec) }

    private func formatRate(_ bytes: Double) -> String {
        let mb = bytes / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB/s", mb) }
        let kb = bytes / 1_024
        return String(format: "%.0f KB/s", kb)
    }
}

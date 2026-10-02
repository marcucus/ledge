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

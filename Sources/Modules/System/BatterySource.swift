import Foundation
import IOKit.ps

// MARK: — BatterySource

//
// Uses IOPSNotificationCreateRunLoopSource — the OS pushes a notification
// whenever battery state changes (charge level, plug state, etc.).
// Zero polling: we only read on demand when the OS fires an event.

/// Event-driven battery reader using IOKit power source notifications.
final class BatterySource {
    /// Called on each state change with the latest snapshot.
    var onUpdate: ((BatteryStats) -> Void)?

    private var runLoopSource: CFRunLoopSource?

    // MARK: — Lifecycle

    func start() {
        // passUnretained is safe here: BatterySource is owned by SystemModule which
        // outlives the run loop source. stop() removes the source before dealloc.
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        runLoopSource = IOPSNotificationCreateRunLoopSource(batteryCallback, ctx)?.takeRetainedValue()
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        // Deliver initial value immediately
        notifyUpdate()
    }

    func stop() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        runLoopSource = nil
    }

    // MARK: — Read

    func notifyUpdate() {
        onUpdate?(readStats())
    }

    private func readStats() -> BatteryStats {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)
                .takeUnretainedValue() as? [String: Any] else { continue }

            let pct = desc[kIOPSCurrentCapacityKey] as? Int
            let isCharging = (desc[kIOPSIsChargingKey] as? Bool) ?? false
            let cycles = desc["Cycle Count"] as? Int

            return BatteryStats(percentage: pct, isCharging: isCharging, cycleCount: cycles)
        }
        return .unavailable
    }
}

// MARK: — C callback (can't be a closure or method)

private func batteryCallback(_ context: UnsafeMutableRawPointer?) {
    guard let ctx = context else { return }
    let source = Unmanaged<BatterySource>.fromOpaque(ctx).takeUnretainedValue()
    source.notifyUpdate()
}

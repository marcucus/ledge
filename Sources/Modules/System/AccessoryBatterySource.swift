import Foundation

// MARK: — AccessoryBatterySource

//
// Accessory battery levels change rarely (slow discharge), so a slow periodic
// refresh (60 s) is acceptable here — unlike CPU/RAM/network which need ~2 Hz.
// Like PollingSource, sampling only runs while the panel is open: the module
// calls beginPolling()/endPolling() from its content view's onAppear/onDisappear
// so nothing is polled at rest.

/// Periodically samples connected Bluetooth accessories' battery levels.
final class AccessoryBatterySource {
    var onUpdate: (([AccessoryBattery]) -> Void)?

    private var timer: Timer?

    /// Start sampling at `interval` seconds (default 60 s — battery drains slowly).
    func beginPolling(interval: TimeInterval = 60) {
        guard timer == nil else { return }
        sample()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func endPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func sample() {
        onUpdate?(SystemObserver.currentAccessoryBatteries())
    }
}

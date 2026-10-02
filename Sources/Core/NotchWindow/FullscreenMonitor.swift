import AppKit
import CoreGraphics

/// Détecte sans polling si l'app au premier plan couvre entièrement l'écran ciblé.
/// Les métadonnées de fenêtres CoreGraphics suffisent : aucune capture d'écran n'est effectuée.
@MainActor
final class FullscreenMonitor {
    struct WindowSnapshot {
        let ownerPID: pid_t
        let layer: Int
        let alpha: Double
        let bounds: CGRect
    }

    private let onChange: (Bool) -> Void
    private var workspaceObservers: [NSObjectProtocol] = []
    private var targetScreen: NSScreen?
    private var lastValue: Bool?
    private var refreshTask: Task<Void, Never>?

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
    }

    deinit {
        refreshTask?.cancel()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
    }

    func start() {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]
        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleRefresh() }
            }
        }
        scheduleRefresh(delay: .zero)
    }

    func updateTargetScreen(_ screen: NSScreen?) {
        targetScreen = screen
        scheduleRefresh(delay: .zero)
    }

    private func scheduleRefresh(delay: Duration = .milliseconds(180)) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            refresh()
        }
    }

    private func refresh() {
        guard let displayID = targetScreen?.ledgeDisplayID,
              let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        else {
            publish(false)
            return
        }
        let isFullscreen = Self.isFullscreen(
            screenBounds: CGDisplayBounds(displayID),
            frontmostPID: frontmostPID,
            windows: Self.windowSnapshots()
        )
        publish(isFullscreen)
    }

    private func publish(_ value: Bool) {
        guard value != lastValue else { return }
        lastValue = value
        onChange(value)
    }

    static func isFullscreen(
        screenBounds: CGRect,
        frontmostPID: pid_t,
        windows: [WindowSnapshot]
    ) -> Bool {
        let tolerance: CGFloat = 3
        return windows.contains { window in
            guard window.ownerPID == frontmostPID, window.layer == 0, window.alpha > 0 else { return false }
            return abs(window.bounds.minX - screenBounds.minX) <= tolerance
                && abs(window.bounds.minY - screenBounds.minY) <= tolerance
                && window.bounds.width >= screenBounds.width - tolerance * 2
                && window.bounds.height >= screenBounds.height - tolerance * 2
        }
    }

    private static func windowSnapshots() -> [WindowSnapshot] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return info.compactMap { item in
            guard let owner = item[kCGWindowOwnerPID as String] as? NSNumber,
                  let layer = item[kCGWindowLayer as String] as? NSNumber,
                  let alpha = item[kCGWindowAlpha as String] as? NSNumber,
                  let dictionary = item[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
            else { return nil }
            return WindowSnapshot(
                ownerPID: owner.int32Value,
                layer: layer.intValue,
                alpha: alpha.doubleValue,
                bounds: bounds
            )
        }
    }
}

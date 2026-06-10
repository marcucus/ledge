import AppKit

extension NSScreen {
    var hasNotch: Bool {
        guard #available(macOS 12, *) else { return false }
        return safeAreaInsets.top > 0
            && auxiliaryTopLeftArea != nil
            && auxiliaryTopRightArea != nil
    }

    /// Géométrie calculée de l'encoche, ou nil si cet écran n'en a pas.
    func notchGeometry() -> NotchGeometry? {
        guard #available(macOS 12, *) else { return nil }
        return NotchGeometry.from(
            screenFrame: frame,
            safeAreaInsetsTop: safeAreaInsets.top,
            auxiliaryTopLeftArea: auxiliaryTopLeftArea,
            auxiliaryTopRightArea: auxiliaryTopRightArea
        )
    }

    /// Premier écran avec une encoche physique, ou nil.
    static var withNotch: NSScreen? {
        screens.first { $0.hasNotch }
    }
}

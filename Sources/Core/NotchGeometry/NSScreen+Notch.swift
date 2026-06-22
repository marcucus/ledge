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

    /// Écran par nom localisé (macOS 12+). Retourne nil si non trouvé.
    static func screen(named name: String) -> NSScreen? {
        guard !name.isEmpty else { return nil }
        if #available(macOS 12, *) {
            return screens.first { $0.localizedName == name }
        }
        return nil
    }

    /// Noms localisés de tous les écrans connectés.
    public static var allNames: [String] {
        if #available(macOS 12, *) {
            return screens.map(\.localizedName)
        }
        return screens.enumerated().map { "Display \($0.offset + 1)" }
    }
}

import AppKit

extension NSScreen {
    var ledgeDisplayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { CGDirectDisplayID($0.uint32Value) }
    }

    var ledgeIdentifier: String {
        guard let displayID = ledgeDisplayID,
              let unmanagedUUID = CGDisplayCreateUUIDFromDisplayID(displayID)
        else { return "screen-\(frame.origin.x)-\(frame.origin.y)-\(localizedName)" }
        let uuid = unmanagedUUID.takeRetainedValue()
        return CFUUIDCreateString(nil, uuid) as String
    }

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

    /// Écran correspondant à l'identifiant persistant CoreGraphics.
    static func screen(identifier: String) -> NSScreen? {
        guard !identifier.isEmpty else { return nil }
        return screens.first { $0.ledgeIdentifier == identifier }
    }

    /// Noms localisés de tous les écrans connectés.
    public static var allNames: [String] {
        if #available(macOS 12, *) {
            return screens.map(\.localizedName)
        }
        return screens.indices.map { "Display \($0 + 1)" }
    }

    /// Écrans connectés, avec l'écran intégré en premier puis les externes par nom.
    public static var availableDescriptors: [ScreenDescriptor] {
        screens
            .map(ScreenDescriptor.init)
            .sorted { left, right in
                if left.isBuiltIn != right.isBuiltIn { return left.isBuiltIn }
                let nameOrder = left.name.localizedCaseInsensitiveCompare(right.name)
                if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
                return left.id < right.id
            }
    }
}

import Foundation

struct CompositionModuleOrders: Codable {
    var focused: [String]
    var panoramic: [String]
    var immersive: [String]

    static let defaults = Self(
        focused: SettingsStore.defaultModuleOrder,
        panoramic: SettingsStore.defaultModuleOrder,
        immersive: SettingsStore.defaultModuleOrder
    )
}

extension SettingsStore {
    static let defaultFocusedModulePlacements = defaultPlacements(
        bar: ["media", "timers"],
        grid: ["dropzone", "clipboard", "shortcuts", "calendar", "notes"]
    )

    static let defaultPanoramicModulePlacements = defaultPlacements(
        bar: ["media", "timers", "dropzone", "clipboard", "shortcuts", "calendar", "notes"],
        grid: []
    )

    static let defaultImmersiveModulePlacements = defaultPlacements(
        bar: ["media", "timers", "calendar"],
        grid: ["dropzone", "clipboard", "shortcuts", "notes"]
    )

    private static func defaultPlacements(bar: [String], grid: [String]) -> [String: Int] {
        var placements = Dictionary(uniqueKeysWithValues: bar.map { ($0, ModulePlacement.bar.rawValue) })
        for id in grid {
            placements[id] = ModulePlacement.grid.rawValue
        }
        return placements
    }

    /// Applique un thème nommé : couleur d'accent + opacité + rayon des coins en une fois.
    public func apply(_ theme: Theme) {
        hudUseSystemAccent = false
        hudAccentColorComponents = theme.accent
        panelOpacity = max(theme.panelOpacity, 0.92)
        cornerRadius = theme.cornerRadius
    }

    /// `id` du thème dont tous les réglages correspondent à l'état courant, sinon `nil`.
    public var activeThemeID: String? {
        guard !hudUseSystemAccent, hudAccentColorComponents.count >= 3 else { return nil }
        let tolerance = 0.005
        return Theme.all.first { theme in
            abs(hudAccentColorComponents[0] - theme.accent[0]) < tolerance &&
                abs(hudAccentColorComponents[1] - theme.accent[1]) < tolerance &&
                abs(hudAccentColorComponents[2] - theme.accent[2]) < tolerance &&
                abs(panelOpacity - theme.panelOpacity) < tolerance &&
                abs(cornerRadius - theme.cornerRadius) < tolerance
        }?.id
    }

    public func modulePlacement(_ id: String, in composition: PanelComposition) -> ModulePlacement {
        let rawValue = placements(for: composition)[id] ?? ModulePlacement.hidden.rawValue
        return ModulePlacement(rawValue: rawValue) ?? .hidden
    }

    public func setModulePlacement(_ placement: ModulePlacement, for id: String, in composition: PanelComposition) {
        switch composition {
        case .focused: focusedModulePlacements[id] = placement.rawValue
        case .panoramic: panoramicModulePlacements[id] = placement.rawValue
        case .immersive: immersiveModulePlacements[id] = placement.rawValue
        }
    }

    public func moduleOrder(in composition: PanelComposition) -> [String] {
        let storedOrder: [String]
        switch composition {
        case .focused: storedOrder = compositionModuleOrders.focused
        case .panoramic: storedOrder = compositionModuleOrders.panoramic
        case .immersive: storedOrder = compositionModuleOrders.immersive
        }
        return storedOrder + Self.defaultModuleOrder.filter { !storedOrder.contains($0) }
    }

    public func moveModule(_ id: String, by offset: Int, in composition: PanelComposition) {
        var order = moduleOrder(in: composition)
        let placement = modulePlacement(id, in: composition)
        let peers = order.filter { modulePlacement($0, in: composition) == placement }
        guard let peerIndex = peers.firstIndex(of: id) else { return }
        let targetIndex = peerIndex + offset
        guard peers.indices.contains(targetIndex),
              let source = order.firstIndex(of: id),
              let destination = order.firstIndex(of: peers[targetIndex])
        else { return }
        order.swapAt(source, destination)
        setModuleOrder(order, in: composition)
    }

    public func showsModuleGrid(in composition: PanelComposition) -> Bool {
        switch composition {
        case .focused: focusedShowsModuleGrid
        case .panoramic: panoramicShowsModuleGrid
        case .immersive: immersiveShowsModuleGrid
        }
    }

    public func setShowsModuleGrid(_ isVisible: Bool, in composition: PanelComposition) {
        switch composition {
        case .focused: focusedShowsModuleGrid = isVisible
        case .panoramic: panoramicShowsModuleGrid = isVisible
        case .immersive: immersiveShowsModuleGrid = isVisible
        }
    }

    private func placements(for composition: PanelComposition) -> [String: Int] {
        switch composition {
        case .focused: focusedModulePlacements
        case .panoramic: panoramicModulePlacements
        case .immersive: immersiveModulePlacements
        }
    }

    private func setModuleOrder(_ order: [String], in composition: PanelComposition) {
        switch composition {
        case .focused: compositionModuleOrders.focused = order
        case .panoramic: compositionModuleOrders.panoramic = order
        case .immersive: compositionModuleOrders.immersive = order
        }
    }
}

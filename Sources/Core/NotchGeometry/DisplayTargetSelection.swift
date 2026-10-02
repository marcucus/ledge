public enum DisplayTargetSelection {
    /// Retourne les identifiants des écrans qui doivent porter une fenêtre Ledge.
    /// `nil` représente la cible automatique (écran intégré avec encoche, sinon écran principal).
    public static func resolvedIdentifiers(
        mode: DisplayTargetMode,
        selectedIdentifiers: [String],
        availableIdentifiers: [String]
    ) -> [String?] {
        switch mode {
        case .automatic:
            return [nil]
        case .all:
            return availableIdentifiers.isEmpty ? [nil] : availableIdentifiers.map(Optional.some)
        case .selected:
            let selected = Set(selectedIdentifiers)
            let connected = availableIdentifiers.filter(selected.contains)
            return connected.isEmpty ? [nil] : connected.map(Optional.some)
        }
    }
}

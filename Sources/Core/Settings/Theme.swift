import Foundation

/// Thème nommé : un preset qui regroupe plusieurs réglages d'apparence appliqués d'un seul clic
/// (couleur d'accent, opacité du panneau, rayon des coins). Voir `SettingsStore.apply(_:)`.
public struct Theme: Identifiable, Equatable {
    public let id: String
    public let nameKey: String
    /// Composantes RGB (0–1) de la couleur d'accent.
    public let accent: [Double]
    /// Opacité du fond du panneau (0,7–1,0, comme le réglage `panelOpacity`).
    public let panelOpacity: Double
    /// Rayon des coins bas du panneau (4–24, comme le réglage `cornerRadius`).
    public let cornerRadius: Double

    public init(
        id: String,
        nameKey: String,
        accent: [Double],
        panelOpacity: Double,
        cornerRadius: Double
    ) {
        self.id = id
        self.nameKey = nameKey
        self.accent = accent
        self.panelOpacity = panelOpacity
        self.cornerRadius = cornerRadius
    }

    public static let all: [Theme] = [
        Theme(id: "midnight", nameKey: "settings.appearance.theme.midnight",
              accent: [0.20, 0.40, 0.95], panelOpacity: 0.82, cornerRadius: 18),
        Theme(id: "solar", nameKey: "settings.appearance.theme.solar",
              accent: [1.0, 0.58, 0.0], panelOpacity: 1.0, cornerRadius: 12),
        Theme(id: "forest", nameKey: "settings.appearance.theme.forest",
              accent: [0.20, 0.72, 0.40], panelOpacity: 0.92, cornerRadius: 14),
        Theme(id: "amethyst", nameKey: "settings.appearance.theme.amethyst",
              accent: [0.66, 0.34, 0.88], panelOpacity: 0.88, cornerRadius: 20),
        Theme(id: "rose", nameKey: "settings.appearance.theme.rose",
              accent: [1.0, 0.30, 0.50], panelOpacity: 0.95, cornerRadius: 22),
        Theme(id: "graphite", nameKey: "settings.appearance.theme.graphite",
              accent: [0.56, 0.56, 0.58], panelOpacity: 1.0, cornerRadius: 8),
    ]
}

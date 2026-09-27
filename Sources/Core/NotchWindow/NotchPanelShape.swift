import SwiftUI

/// Forme du panneau Ledge.
///
/// Les coins hauts utilisent une "oreille" (topEar px de chaque côté) : la fenêtre est plus
/// large que le contenu, ce qui crée un carré dans chaque coin haut. Le traitement est le
/// même que pour les coins bas : contrôle au vertex extérieur → arc concave visible.
public struct NotchPanelShape: Shape {
    public var topEar: CGFloat
    public var bottomRadius: CGFloat

    public init(topEar: CGFloat, bottomRadius: CGFloat) {
        self.topEar = topEar
        self.bottomRadius = bottomRadius
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topEar, bottomRadius) }
        set { topEar = newValue.first; bottomRadius = newValue.second }
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        // La fenêtre AppKit change de taille à chaque image de l'animation. Les rayons doivent
        // donc rester valides même quand sa hauteur est encore proche de celle de l'encoche.
        // Sans ce bornage, `ear + bottom` dépasse la hauteur disponible et les deux segments
        // verticaux se croisent brièvement — surtout visible avec la composition Immersive.
        let ear = min(max(topEar, 0), rect.width / 2, rect.height / 2)
        let availableHeight = max(rect.height - ear, 0)
        let availableHalfWidth = max((rect.width - ear * 2) / 2, 0)
        let bottom = min(max(bottomRadius, 0), availableHeight, availableHalfWidth)

        // ── Coin haut-gauche (flare out vers le menu bar)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + ear, y: rect.minY + ear),
            control: CGPoint(x: rect.minX + ear, y: rect.minY)
        )

        // ── Bord gauche du corps
        path.addLine(to: CGPoint(x: rect.minX + ear, y: rect.maxY - bottom))

        // ── Coin bas-gauche
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + ear + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + ear, y: rect.maxY)
        )

        // ── Bord inférieur
        path.addLine(to: CGPoint(x: rect.maxX - ear - bottom, y: rect.maxY))

        // ── Coin bas-droit
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - ear, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - ear, y: rect.maxY)
        )

        // ── Bord droit du corps
        path.addLine(to: CGPoint(x: rect.maxX - ear, y: rect.minY + ear))

        // ── Coin haut-droit (flare out)
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - ear, y: rect.minY)
        )

        // ── Bord supérieur (fermeture horizontale)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        path.closeSubpath()
        return path
    }
}

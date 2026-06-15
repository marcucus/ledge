import SwiftUI

/// Forme du panneau Notchy.
///
/// Les coins hauts utilisent une "oreille" (topEar px de chaque côté) : la fenêtre est plus
/// large que le contenu, ce qui crée un carré dans chaque coin haut. Le traitement est le
/// même que pour les coins bas : contrôle au vertex extérieur → arc concave visible.
struct NotchPanelShape: Shape {
    var topEar: CGFloat       // largeur de l'oreille en haut (ex. 12 px)
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topEar, bottomRadius) }
        set { topEar = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let e = topEar
        let b = bottomRadius

        // ── Coin haut-gauche : carré (oreille) + même traitement que les coins bas
        //    Contrôle au vertex EXTÉRIEUR (0, 0) → arc concave depuis l'extérieur
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + e))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + e, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        // ── Bord supérieur
        p.addLine(to: CGPoint(x: rect.maxX - e, y: rect.minY))

        // ── Coin haut-droit : même traitement
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + e),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // ── Bord droit
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - b))

        // ── Coin bas-droit : même traitement (référence)
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - b, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // ── Bord inférieur
        p.addLine(to: CGPoint(x: rect.minX + b, y: rect.maxY))

        // ── Coin bas-gauche
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - b),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        p.closeSubpath()
        return p
    }
}

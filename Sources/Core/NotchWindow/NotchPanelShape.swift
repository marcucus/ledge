import SwiftUI

/// Forme du panneau Ledge.
///
/// Les coins hauts utilisent une "oreille" (topEar px de chaque côté) : la fenêtre est plus
/// large que le contenu, ce qui crée un carré dans chaque coin haut. Le traitement est le
/// même que pour les coins bas : contrôle au vertex extérieur → arc concave visible.
struct NotchPanelShape: Shape {
    var topEar: CGFloat // largeur de l'oreille en haut (ex. 12 px)
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topEar, bottomRadius) }
        set { topEar = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let ear = topEar
        let bottom = bottomRadius

        // ── Coin haut-gauche : carré (oreille) + même traitement que les coins bas
        //    Contrôle au vertex EXTÉRIEUR (0, 0) → arc concave depuis l'extérieur
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + ear))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + ear, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        // ── Bord supérieur
        path.addLine(to: CGPoint(x: rect.maxX - ear, y: rect.minY))

        // ── Coin haut-droit : même traitement
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + ear),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        // ── Bord droit
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))

        // ── Coin bas-droit : même traitement (référence)
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )

        // ── Bord inférieur
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))

        // ── Coin bas-gauche
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        path.closeSubpath()
        return path
    }
}

import CoreGraphics

/// Représentation calculée de la géométrie de l'encoche d'un écran.
struct NotchGeometry: Equatable {
    /// Rect de l'encoche en coordonnées écran (y vers le haut, origine bas-gauche).
    let notchRect: CGRect
    let screenFrame: CGRect

    /// Bord supérieur du centre de l'encoche — ancre haute du panneau Ledge.
    var anchorPoint: CGPoint {
        CGPoint(x: notchRect.midX, y: notchRect.maxY)
    }

    /// Calcule la géométrie depuis les valeurs brutes de NSScreen.
    /// Fonction pure — testable sans instance NSScreen réelle.
    static func from(
        screenFrame: CGRect,
        safeAreaInsetsTop: CGFloat,
        auxiliaryTopLeftArea: CGRect?,
        auxiliaryTopRightArea: CGRect?
    ) -> NotchGeometry? {
        guard safeAreaInsetsTop > 0,
              let leftArea = auxiliaryTopLeftArea,
              let rightArea = auxiliaryTopRightArea,
              rightArea.minX > leftArea.maxX
        else { return nil }

        let rect = CGRect(
            x: leftArea.maxX,
            y: screenFrame.maxY - safeAreaInsetsTop,
            width: rightArea.minX - leftArea.maxX,
            height: safeAreaInsetsTop
        )
        return NotchGeometry(notchRect: rect, screenFrame: screenFrame)
    }
}

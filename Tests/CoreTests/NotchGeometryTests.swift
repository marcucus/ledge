import CoreGraphics
import Testing
@testable import Core

@Suite struct NotchGeometryTests {
    // Valeurs fictives réalistes (MacBook Pro 14", résolution logique)
    private let screenFrame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    private let safeAreaTop: CGFloat = 32
    // Zones auxiliaires : gauche de 0 à 200, droite de 380 à 580
    // → encoche attendue : x=200, y=950, width=180, height=32
    private let leftArea = CGRect(x: 0, y: 950, width: 200, height: 32)
    private let rightArea = CGRect(x: 380, y: 950, width: 200, height: 32)

    @Test func detected() {
        let geo = NotchGeometry.from(
            screenFrame: screenFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea
        )
        #expect(geo?.notchRect == CGRect(x: 200, y: 950, width: 180, height: 32))
    }

    @Test func notDetectedWhenSafeAreaZero() {
        let geo = NotchGeometry.from(
            screenFrame: screenFrame,
            safeAreaInsetsTop: 0,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea
        )
        #expect(geo == nil)
    }

    @Test func notDetectedWithoutAuxiliaryAreas() {
        let geo = NotchGeometry.from(
            screenFrame: screenFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryTopLeftArea: nil,
            auxiliaryTopRightArea: nil
        )
        #expect(geo == nil)
    }

    @Test func anchorPointBelowNotchCenter() {
        let geo = NotchGeometry.from(
            screenFrame: screenFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryTopLeftArea: leftArea,
            auxiliaryTopRightArea: rightArea
        )
        // midX = 200 + 180/2 = 290 ; minY = 982 - 32 = 950
        #expect(geo?.anchorPoint == CGPoint(x: 290, y: 950))
    }

    @Test func notDetectedWhenAreasIncoherent() {
        // leftArea et rightArea inversées → rightArea.minX < leftArea.maxX
        let geo = NotchGeometry.from(
            screenFrame: screenFrame,
            safeAreaInsetsTop: safeAreaTop,
            auxiliaryTopLeftArea: rightArea,
            auxiliaryTopRightArea: leftArea
        )
        #expect(geo == nil)
    }
}

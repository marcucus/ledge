@testable import App
import AppKit
import Testing

struct SettingsWindowGeometryTests {
    @Test func savedContentSizeCannotRestoreBelowMinimum() {
        let size = SettingsWindowGeometry.normalizedContentSize(NSSize(width: 613, height: 386))

        #expect(size == NSSize(width: 720, height: 520))
    }

    @Test func restoredWindowIsMovedBackInsideVisibleScreen() {
        let visible = NSRect(x: 0, y: 24, width: 1_440, height: 876)
        let frame = NSRect(x: -180, y: 500, width: 780, height: 560)

        let result = SettingsWindowGeometry.constrainedFrame(frame, to: visible)

        #expect(result.minX == visible.minX)
        #expect(result.maxY <= visible.maxY)
    }
}

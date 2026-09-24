import AppKit
@testable import SystemModule
import Testing

struct SystemObserverTests {
    // MARK: — decodeMediaKey

    /// Construit un évènement `.systemDefined` façon touche média, avec le même encodage
    /// que celui produit par macOS : code sur les bits 16-31 de `data1`, état (down=0xA,
    /// up=0xB) sur les bits 8-15. Sous-type 8 = NX_SUBTYPE_AUX_CONTROL_BUTTONS.
    private func mediaKeyEvent(subtype: Int16 = 8, code: Int, isDown: Bool) -> NSEvent {
        let state = isDown ? 0xA : 0xB
        let data1 = (code << 16) | (state << 8)
        guard let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: 0, context: nil, subtype: subtype, data1: data1, data2: 0
        ) else {
            preconditionFailure("NSEvent.otherEvent returned nil")
        }
        return event
    }

    @Test func decodesVolumeUpKeyDown() {
        let event = mediaKeyEvent(code: 0, isDown: true)
        let decoded = SystemObserver.decodeMediaKey(event)
        #expect(decoded?.code == 0)
        #expect(decoded?.isDown == true)
    }

    @Test func decodesMuteKeyUp() {
        let event = mediaKeyEvent(code: 7, isDown: false)
        let decoded = SystemObserver.decodeMediaKey(event)
        #expect(decoded?.code == 7)
        #expect(decoded?.isDown == false)
    }

    @Test func rejectsUnknownKeyCode() {
        let event = mediaKeyEvent(code: 99, isDown: true)
        #expect(SystemObserver.decodeMediaKey(event) == nil)
    }

    @Test func rejectsWrongSubtype() {
        let event = mediaKeyEvent(subtype: 1, code: 0, isDown: true)
        #expect(SystemObserver.decodeMediaKey(event) == nil)
    }

    // MARK: — clamp

    @Test func clampKeepsValueInRange() {
        #expect(SystemObserver.clamp(0.5) == 0.5)
    }

    @Test func clampLimitsAboveOne() {
        #expect(SystemObserver.clamp(1.5) == 1.0)
    }

    @Test func clampLimitsBelowZero() {
        #expect(SystemObserver.clamp(-0.5) == 0.0)
    }
}

import CoreAudio
import Foundation
import IOKit.pwr_mgt

// MARK: — ToggleKind

/// Identifies a supported quick-toggle action.
public enum ToggleKind: String, CaseIterable {
    case caffeine
    case mute
}

// MARK: — QuickToggle

/// A self-contained toggle with a readable state and an async action closure.
@MainActor
public struct QuickToggle: Identifiable {
    public let id: ToggleKind
    public var icon: String
    public let labelKey: String
    public var isOn: Bool
    /// Flips the toggle state; may throw / be a no-op if the API is unavailable.
    public var action: @MainActor () async -> Void

    public init(
        id: ToggleKind, icon: String, labelKey: String, isOn: Bool,
        toggle: @escaping @MainActor () async -> Void
    ) {
        self.id = id; self.icon = icon; self.labelKey = labelKey
        self.isOn = isOn; self.action = toggle
    }
}

// MARK: — Caffeine (IOPMAssertion)

/// Manages a "PreventSystemSleep" assertion so the Mac stays awake.
final class CaffeineManager {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    func enable() {
        guard !isActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Notchy Caffeine" as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess { isActive = true }
    }

    func disable() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        assertionID = 0
        isActive = false
    }

    func toggle() {
        isActive ? disable() : enable()
    }
}

// MARK: — Mute (CoreAudio)

/// Reads and writes the system output device mute state via CoreAudio.
enum MuteManager {
    /// Returns current mute state for the default output device, or nil if unavailable.
    static func isMuted() -> Bool? {
        guard let deviceID = defaultOutputDevice() else { return nil }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted)
        return status == noErr ? muted != 0 : nil
    }

    /// Toggles the mute state. Returns the new state, or nil on failure.
    @discardableResult
    static func toggle() -> Bool? {
        guard let deviceID = defaultOutputDevice() else { return nil }
        guard var current = isMuted() else { return nil }
        current.toggle()
        var newValue = UInt32(current ? 1 : 0)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectSetPropertyData(deviceID, &addr, 0, nil, size, &newValue)
        return status == noErr ? current : nil
    }

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        )
        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
}

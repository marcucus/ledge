import CoreAudio
import Foundation

// MARK: — MicrophoneSource

//
// Uses AudioObjectAddPropertyListenerBlock on kAudioDevicePropertyDeviceIsRunningSomewhere —
// CoreAudio pushes a notification whenever any process starts or stops using the default
// input device. Zero polling: we only read on demand when the OS fires the listener.

/// Event-driven microphone-usage reader using a CoreAudio property listener.
///
/// `kAudioDevicePropertyDeviceIsRunningSomewhere` is a public CoreAudio property that
/// reports whether the default input device is currently in use by *any* process on the
/// system (not just Ledge). There is no public API to know *which* app is using it, or to
/// detect screen recording — this only reports microphone activity.
final class MicrophoneSource {
    /// Called whenever the "in use" state changes, with the latest snapshot.
    var onUpdate: ((Bool) -> Void)?

    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var observedDevice = AudioDeviceID(kAudioObjectUnknown)

    // MARK: — Lifecycle

    func start() {
        installListener()
        notifyUpdate()
    }

    func stop() {
        removeListener()
    }

    // MARK: — Read

    func notifyUpdate() {
        onUpdate?(Self.isInUse())
    }

    // MARK: — Listener (échoue proprement si le périphérique est inconnu)

    private func installListener() {
        let device = Self.defaultInputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        observedDevice = device

        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.notifyUpdate()
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(device, &addr, DispatchQueue.main, block)
    }

    private func removeListener() {
        guard observedDevice != AudioDeviceID(kAudioObjectUnknown), let block = listenerBlock else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(observedDevice, &addr, DispatchQueue.main, block)
        listenerBlock = nil
        observedDevice = AudioDeviceID(kAudioObjectUnknown)
    }

    // MARK: — Low-level CoreAudio reads

    private nonisolated static func isInUse() -> Bool {
        let device = defaultInputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value) == noErr else { return false }
        return value == 1
    }

    private nonisolated static func defaultInputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        )
        return deviceID
    }
}

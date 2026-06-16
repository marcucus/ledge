import CoreAudio

/// Couche bas niveau CoreAudio (volume système de la sortie par défaut).
/// Fonctions C → `nonisolated static`, sans état d'instance.
extension SystemObserver {
    nonisolated static func currentVolume() -> Double {
        let device = defaultOutputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return -1 }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &volume) == noErr {
            return Double(volume)
        }
        addr.mElement = 1 // certains appareils n'exposent le volume que par canal
        guard AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &volume) == noErr else {
            return -1
        }
        return Double(volume)
    }

    nonisolated static func setVolume(_ value: Float) {
        let device = defaultOutputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        var clamped = clamp(value)
        let size = UInt32(MemoryLayout<Float32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectSetPropertyData(device, &addr, 0, nil, size, &clamped) != noErr {
            for channel in [UInt32(1), UInt32(2)] {
                addr.mElement = channel
                _ = AudioObjectSetPropertyData(device, &addr, 0, nil, size, &clamped)
            }
        }
        if clamped > 0.0001 { setMute(false) }
    }

    nonisolated static func isMuted() -> Bool {
        let device = defaultOutputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &value)
        return value == 1
    }

    nonisolated static func setMute(_ muted: Bool) {
        let device = defaultOutputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        var value: UInt32 = muted ? 1 : 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(
            device, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
    }

    private nonisolated static func defaultOutputDevice() -> AudioDeviceID {
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        )
        return deviceID
    }
}

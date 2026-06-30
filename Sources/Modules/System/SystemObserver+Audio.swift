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

    // MARK: — Listener événementiel (remplace le polling pour le volume)

    private nonisolated(unsafe) static var volumeListenerDevice = AudioDeviceID(kAudioObjectUnknown)
    private nonisolated(unsafe) static var volumeListenerBlock: AudioObjectPropertyListenerBlock?
    private nonisolated(unsafe) static var deviceListenerBlock: AudioObjectPropertyListenerBlock?

    private nonisolated static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private nonisolated static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    /// Branche un listener CoreAudio sur le volume/mute de la sortie par défaut : capte
    /// tout changement (Centre de contrôle, AirPods, AppleScript…) sans aucun polling.
    nonisolated static func installVolumeListener() {
        removeVolumeListener()
        let device = defaultOutputDevice()
        guard device != AudioDeviceID(kAudioObjectUnknown) else { return }
        volumeListenerDevice = device
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            Task { @MainActor in
                guard let observer = shared, observer.suppressNativeHUD else { return }
                let volume = currentVolume()
                if volume >= 0 { observer.emitVolume(volume, muted: isMuted()) }
            }
        }
        volumeListenerBlock = block
        var volAddr = volumeAddress
        var muteAddr = muteAddress
        AudioObjectAddPropertyListenerBlock(device, &volAddr, DispatchQueue.main, block)
        AudioObjectAddPropertyListenerBlock(device, &muteAddr, DispatchQueue.main, block)
    }

    nonisolated static func removeVolumeListener() {
        guard volumeListenerDevice != AudioDeviceID(kAudioObjectUnknown),
              let block = volumeListenerBlock else { return }
        var volAddr = volumeAddress
        var muteAddr = muteAddress
        AudioObjectRemovePropertyListenerBlock(volumeListenerDevice, &volAddr, DispatchQueue.main, block)
        AudioObjectRemovePropertyListenerBlock(volumeListenerDevice, &muteAddr, DispatchQueue.main, block)
        volumeListenerBlock = nil
        volumeListenerDevice = AudioDeviceID(kAudioObjectUnknown)
    }

    /// Réinstalle le listener volume quand la sortie par défaut change (ex. bascule vers AirPods).
    nonisolated static func installDefaultDeviceListener() {
        removeDefaultDeviceListener()
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { _, _ in installVolumeListener() }
        deviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block)
    }

    nonisolated static func removeDefaultDeviceListener() {
        guard let block = deviceListenerBlock else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, DispatchQueue.main, block
        )
        deviceListenerBlock = nil
    }
}

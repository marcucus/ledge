import AppKit
import Core
import CoreGraphics

/// Monitors system volume and display brightness.
///
/// When `suppressNativeHUD` is true (réglage activé) and Accessibility is granted,
/// a CGEventTap intercepts the volume/brightness media keys, **consumes** them so macOS
/// never shows its own overlay, and applies the change itself (CoreAudio / DisplayServices)
/// before showing Ledge's compact HUD instead.
@MainActor
public final class SystemObserver {
    public var onVolumeChange: ((Double, Bool) -> Void)?
    public var onBrightnessChange: ((Double) -> Void)?

    public var suppressNativeHUD = false {
        didSet { updateEventTap() }
    }

    // Accès depuis le callback C (non-isolé) — fort pour survivre à l'owner qui l'a créé.
    // Non-private : lu depuis SystemObserver+Audio.swift (listener CoreAudio).
    nonisolated(unsafe) static var shared: SystemObserver?
    private nonisolated(unsafe) static var activeTap: CFMachPort?

    private nonisolated(unsafe) var pollTimer: Timer?
    private nonisolated(unsafe) var globalMonitor: Any?
    private nonisolated(unsafe) var eventTap: CFMachPort?
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?

    private var lastBrightness: Double = -1
    private var didPromptAX = false
    private var settingObserver: NSObjectProtocol?

    private let settings: SettingsStore

    public init(settings: SettingsStore) {
        self.settings = settings
        SystemObserver.shared = self
        SystemObserver.loadDisplayServices()
    }

    public func start() {
        // Init à la valeur courante pour ne pas déclencher de HUD au lancement
        lastBrightness = SystemObserver.currentBrightness()
        installKeyboardMonitor()
        observeSettingChanges()
        // Déclenche updateEventTap() via didSet → installe tap + polling si activé.
        suppressNativeHUD = settings.hudReplaceSystem
    }

    public func stop() {
        stopPolling()
        globalMonitor.map { NSEvent.removeMonitor($0) }
        globalMonitor = nil
        removeEventTap()
        SystemObserver.removeVolumeListener()
        SystemObserver.removeDefaultDeviceListener()
        settingObserver.map { NotificationCenter.default.removeObserver($0) }
        settingObserver = nil
        SystemObserver.shared = nil
    }

    // MARK: — Observation (monitor clavier + réglage)

    private func installKeyboardMonitor() {
        // Monitor clavier immédiat (utile quand le tap n'est pas actif, ex. pas de
        // permission Accessibilité). Quand le tap est actif, il consomme l'événement
        // et ce monitor ne reçoit rien → pas de double déclenchement.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard let key = SystemObserver.decodeMediaKey(event), key.isDown else { return }
            Task { @MainActor [weak self] in
                guard let self, suppressNativeHUD else { return }
                // Laisse macOS appliquer le changement avant de lire la valeur
                try? await Task.sleep(for: HUDTuning.keyApplyDelay)
                readAndEmit(for: key.code)
            }
        }
    }

    private func observeSettingChanges() {
        // Le réglage "remplacer HUD macOS" est écrit dans UserDefaults par le SettingsStore ;
        // on réagit à chaud pour activer/couper le tap et le polling.
        settingObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let suppress = settings.hudReplaceSystem
                if suppressNativeHUD != suppress {
                    suppressNativeHUD = suppress
                } else if suppressNativeHUD {
                    // hudBrightnessManualOnly a peut-être changé : réévalue la cadence du poll.
                    if !settings.hudBrightnessManualOnly { lastBrightness = SystemObserver.currentBrightness() }
                    startPolling()
                }
            }
        }
    }

    /// Lit la valeur courante après une touche média et l'émet vers le HUD.
    private func readAndEmit(for keyCode: Int) {
        switch keyCode {
        case MediaKey.brightnessUp, MediaKey.brightnessDown:
            let brightness = SystemObserver.currentBrightness()
            if brightness >= 0 { emitBrightness(brightness) }
        default:
            let volume = SystemObserver.currentVolume()
            if volume >= 0 { emitVolume(volume, muted: SystemObserver.isMuted()) }
        }
    }

    // MARK: — Polling (uniquement quand le remplacement HUD est actif)
    //
    // Le volume est désormais détecté par un listener CoreAudio événementiel
    // (cf. installVolumeListener) — il ne reste à interroger périodiquement que :
    //   - la luminosité, et seulement si l'utilisateur a désactivé le mode "clavier
    //     uniquement" (hudBrightnessManualOnly, activé par défaut → 0 lecture au repos) ;
    //   - la permission Accessibilité, pour réinstaller le tap dès qu'elle est accordée.
    // Cadence rapide seulement quand la luminosité est réellement surveillée ; sinon un
    // simple battement lent suffit pour le recheck Accessibilité.

    private func startPolling() {
        let interval = settings.hudBrightnessManualOnly ? HUDTuning.axRecheckInterval : HUDTuning.pollInterval
        guard pollTimer == nil || pollTimer?.timeInterval != interval else { return }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollAll() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollAll() {
        // Réinstalle le tap si la permission vient d'être accordée après coup
        if suppressNativeHUD, eventTap == nil, AXIsProcessTrusted() {
            installEventTap()
        }
        guard suppressNativeHUD, !settings.hudBrightnessManualOnly else { return }
        let brightness = SystemObserver.currentBrightness()
        if brightness >= 0, abs(brightness - lastBrightness) > HUDTuning.brightnessThreshold {
            emitBrightness(brightness)
        }
    }

    // MARK: — Émission (MainActor), appelée par le tap / le polling / le monitor

    // Non-private : appelé depuis SystemObserver+Audio.swift (listener CoreAudio).
    func emitVolume(_ value: Double, muted: Bool) {
        onVolumeChange?(value, muted)
    }

    private func emitBrightness(_ value: Double) {
        lastBrightness = value
        onBrightnessChange?(value)
    }

    // MARK: — Décodage des touches média

    /// Décode un événement `systemDefined` en (code de touche média, appui/relâche).
    nonisolated static func decodeMediaKey(_ event: NSEvent) -> (code: Int, isDown: Bool)? {
        guard event.subtype.rawValue == MediaKey.subtype else { return nil }
        let code = Int((event.data1 & 0xFFFF_0000) >> 16)
        guard MediaKey.all.contains(code) else { return nil }
        let isDown = ((event.data1 & 0xFF00) >> 8) == 0xA
        return (code, isDown)
    }

    /// Applique le changement déclenché par une touche média interceptée par le tap.
    /// Retourne `true` si la touche est consommée (→ supprime le HUD natif macOS).
    nonisolated static func applyMediaKey(code: Int, fine: Bool) -> Bool {
        let step = fine ? HUDTuning.fineStep : HUDTuning.volumeStep
        switch code {
        case MediaKey.volumeUp, MediaKey.volumeDown:
            let delta = code == MediaKey.volumeUp ? step : -step
            let value = clamp(Float(max(0, currentVolume())) + delta)
            setVolume(value)
            let muted = value < 0.0001
            Task { @MainActor in shared?.emitVolume(Double(value), muted: muted) }
            return true
        case MediaKey.mute:
            let muted = !isMuted()
            setMute(muted)
            let value = currentVolume()
            Task { @MainActor in shared?.emitVolume(value, muted: muted) }
            return true
        case MediaKey.brightnessUp, MediaKey.brightnessDown:
            var current = Float(currentBrightness())
            if current < 0 { current = HUDTuning.defaultBrightness }
            let delta = code == MediaKey.brightnessUp ? step : -step
            let value = clamp(current + delta)
            setBrightness(value)
            Task { @MainActor in shared?.emitBrightness(Double(value)) }
            return true
        default:
            return false
        }
    }

    nonisolated static func clamp(_ value: Float) -> Float {
        max(0, min(1, value))
    }

    // MARK: — CGEventTap (interception des touches média)

    private func updateEventTap() {
        guard suppressNativeHUD else {
            removeEventTap()
            stopPolling()
            SystemObserver.removeVolumeListener()
            SystemObserver.removeDefaultDeviceListener()
            return
        }
        startPolling()
        SystemObserver.installVolumeListener()
        SystemObserver.installDefaultDeviceListener()
        if AXIsProcessTrusted() {
            installEventTap()
        } else {
            removeEventTap()
            promptAccessibilityOnce()
        }
    }

    private func promptAccessibilityOnce() {
        guard !didPromptAX else { return }
        didPromptAX = true
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func installEventTap() {
        guard eventTap == nil else { return }
        let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << MediaKey.eventType,
            callback: { _, type, event, _ -> Unmanaged<CGEvent>? in
                SystemObserver.handleTapEvent(type: type, event: event)
            },
            userInfo: nil
        )
        guard let tap else { return }
        eventTap = tap
        SystemObserver.activeTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        source.map { CFRunLoopAddSource(CFRunLoopGetMain(), $0, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Callback C du tap : applique la touche et la consomme, ou laisse passer l'événement.
    private nonisolated static func handleTapEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            activeTap.map { CGEvent.tapEnable(tap: $0, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == MediaKey.eventType,
              let nsEvent = NSEvent(cgEvent: event),
              let key = decodeMediaKey(nsEvent), key.isDown
        else { return Unmanaged.passUnretained(event) }
        let mods = nsEvent.modifierFlags
        let fine = mods.contains(.shift) && mods.contains(.option)
        return applyMediaKey(code: key.code, fine: fine) ? nil : Unmanaged.passUnretained(event)
    }

    private func removeEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            runLoopSource.map { CFRunLoopRemoveSource(CFRunLoopGetMain(), $0, .commonModes) }
            // Invalider le mach port pour ne pas le fuiter à chaque cycle install/remove.
            CFMachPortInvalidate(tap)
        }
        eventTap = nil
        SystemObserver.activeTap = nil
        runLoopSource = nil
    }
}

// MARK: — Constantes

private enum HUDTuning {
    static let pollInterval: TimeInterval = 0.2
    /// Cadence du battement quand seule la permission Accessibilité doit être resurveillée
    /// (volume événementiel, luminosité non surveillée en mode "clavier uniquement").
    static let axRecheckInterval: TimeInterval = 2.0
    static let keyApplyDelay: Duration = .milliseconds(60)
    static let volumeStep: Float = 1.0 / 16.0
    static let fineStep: Float = 1.0 / 64.0 // Maj+Option : incrément plus fin
    // 5 % : filtre les ajustements automatiques (True Tone, capteur ambiant) qui sont
    // typiquement < 3 % par intervalle de 200 ms. Les touches clavier passent toujours
    // par le chemin direct (emitBrightness) sans passer par ce seuil.
    static let brightnessThreshold = 0.05
    static let defaultBrightness: Float = 0.5 // repli si la lecture échoue
}

/// PRIVATE API — codes des touches média dans un `NSEvent` de sous-type `systemDefined`.
private enum MediaKey {
    static let volumeUp = 0
    static let volumeDown = 1
    static let brightnessUp = 2
    static let brightnessDown = 3
    static let mute = 7
    static let all = [volumeUp, volumeDown, brightnessUp, brightnessDown, mute]
    static let subtype = 8 // sous-type NSEvent des touches média
    static let eventType: UInt32 = 14 // NX_SYSDEFINED (absent de CGEventType)
}

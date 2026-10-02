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
    private var appActivationObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var sessionActivationObserver: NSObjectProtocol?
    private var wakeRecoveryTask: Task<Void, Never>?

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
        observeAppActivations()
        observeWakeEvents()
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
        appActivationObserver.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        appActivationObserver = nil
        wakeObserver.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        wakeObserver = nil
        sessionActivationObserver.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        sessionActivationObserver = nil
        wakeRecoveryTask?.cancel()
        wakeRecoveryTask = nil
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
                    // hudBrightnessManualOnly a peut-être changé : réévalue si le polling
                    // luminosité est réellement nécessaire.
                    if !settings.hudBrightnessManualOnly { lastBrightness = SystemObserver.currentBrightness() }
                    startPolling()
                }
            }
        }
    }

    /// Réévalue la permission Accessibilité quand l'utilisateur change d'application.
    /// Le retour de Réglages Système déclenche notamment cette notification : nul besoin de
    /// réveiller Ledge toutes les deux secondes au repos pour détecter l'autorisation accordée.
    private func observeAppActivations() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.ensureEventTapIsOperational()
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
    //     uniquement" (hudBrightnessManualOnly, activé par défaut → 0 lecture au repos).
    // La permission Accessibilité est réévaluée de façon événementielle au changement
    // d'application, notamment au retour de Réglages Système.

    private func startPolling() {
        guard !settings.hudBrightnessManualOnly else {
            stopPolling()
            return
        }
        guard pollTimer == nil else { return }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: HUDTuning.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollAll() }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollAll() {
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

// MARK: — Récupération après veille

private extension SystemObserver {
    /// Le Mach port d'un CGEventTap peut rester non-nil mais devenir inutilisable après une
    /// veille. Au réveil et au déverrouillage de session, on le recrée avec quelques tentatives
    /// bornées, le temps que WindowServer et les services d'accessibilité redeviennent prêts.
    func observeWakeEvents() {
        let center = NSWorkspace.shared.notificationCenter
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleWakeRecovery() }
        }
        sessionActivationObserver = center.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.scheduleWakeRecovery() }
        }
    }

    func scheduleWakeRecovery() {
        guard suppressNativeHUD else { return }
        wakeRecoveryTask?.cancel()
        removeEventTap()
        SystemObserver.removeVolumeListener()
        SystemObserver.removeDefaultDeviceListener()
        lastBrightness = SystemObserver.currentBrightness()

        wakeRecoveryTask = Task { @MainActor [weak self] in
            let delays: [Duration] = [.milliseconds(250), .seconds(1), .seconds(2)]
            for delay in delays {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
                guard let self, suppressNativeHUD else { return }
                updateEventTap()
                if eventTap.map(CGEvent.tapIsEnabled(tap:)) == true { return }
                removeEventTap()
            }
        }
    }

    func ensureEventTapIsOperational() {
        guard suppressNativeHUD, AXIsProcessTrusted() else { return }
        if let eventTap, CGEvent.tapIsEnabled(tap: eventTap) { return }
        removeEventTap()
        installEventTap()
    }
}

// MARK: — Constantes

private enum HUDTuning {
    static let pollInterval: TimeInterval = 0.2
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

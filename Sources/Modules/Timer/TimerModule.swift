import Core
import Foundation
import SwiftUI
import UserNotifications

@MainActor
@Observable
// La logique reste centralisée, mais les vues, modèles et stockage sont chacun dans leur fichier.
// swiftlint:disable:next type_body_length
public final class TimerModule: NotchModule {
    public let id = "timers"
    public let tabIcon = "timer"
    public let tabLabel: LocalizedStringKey = "module.timers.label"

    public private(set) var entries: [TimerEntry] = []
    public private(set) var pomodoroState: PomodoroState = .init()
    public private(set) var persistenceIssue: TimerPersistenceIssue?
    public var onAmbientUpdate: ((AmbientContent?) -> Void)?
    /// Appelé quand un minuteur (ou une phase Pomodoro) se termine, en plus de la notification
    /// système — laisse à l'appelant (voir `AppDelegate`) la décision d'afficher ou non un peek
    /// selon `SettingsStore.timerFinishedPeekEnabled` (doc 13, Jalon 3, item 20).
    public var onFinished: (() -> Void)?

    @ObservationIgnored private nonisolated(unsafe) var dispatchTimers: [UUID: DispatchSourceTimer] = [:]
    @ObservationIgnored private var pomodoroEntryID: UUID?
    @ObservationIgnored private var didRequestNotificationPermission = false
    @ObservationIgnored private let persistenceStore: TimerPersistenceStore
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var isStarted = false

    /// `persistenceStore` est injectable pour les tests (répertoire temporaire isolé) ; en
    /// production, l'appel sans argument résout toujours `Application Support/Ledge`.
    public init(
        settings: SettingsStore = .shared,
        persistenceStore: TimerPersistenceStore = TimerPersistenceStore()
    ) {
        self.settings = settings
        self.persistenceStore = persistenceStore
    }

    // MARK: — NotchModule

    /// Restaure les timers actifs laissés par une session précédente (doc 13, Jalon 3, item 19).
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        restoreOrResumeTimers()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        for (_, source) in dispatchTimers {
            source.cancel()
        }
        dispatchTimers.removeAll()
        updateAmbient()
    }

    public func makePeekView() -> AnyView {
        AnyView(TimerPeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(TimerContentView(module: self))
    }

    // MARK: — Capture marketing

    /// Injecte des timers de démonstration directement dans l'état observable, sans passer par
    /// `DispatchSourceTimer` ni la persistance disque — utilisé uniquement par `MarketingCapture`
    /// pour produire des rendus déterministes (cf. docs/PLAN-REFONTE-FIDELITE.md).
    package func configureMarketingCapture(entries: [TimerEntry]) {
        self.entries = entries
    }

    deinit {
        for (_, source) in dispatchTimers {
            source.cancel()
        }
        dispatchTimers.removeAll()
    }

    // MARK: — Public API

    public func send(_ action: TimerAction) {
        switch action {
        case let .start(id): startEntry(id)
        case let .pause(id): pauseEntry(id)
        case let .stop(id): stopEntry(id)
        case let .reset(id): resetEntry(id)
        }
    }

    @discardableResult
    public func addTimer(label: String, duration: TimeInterval) -> UUID {
        let entry = TimerEntry(label: label, duration: duration)
        entries.append(entry)
        persist()
        return entry.id
    }

    /// Crée un timer et le démarre immédiatement. Retourne `nil` si la durée est nulle.
    @discardableResult
    public func addAndStart(label: String, duration: TimeInterval) -> UUID? {
        guard duration > 0 else { return nil }
        let id = addTimer(label: label, duration: duration)
        send(.start(id: id))
        return id
    }

    public func removeTimer(id: UUID) {
        stopDispatchTimer(for: id)
        entries.removeAll { $0.id == id }
        updateAmbient()
        persist()
    }

    /// Suppression destructive explicite, distincte de `stop()` qui ne fait que suspendre
    /// l'activité lors d'une désactivation globale ou par profil d'app.
    public func clearAllTimers() {
        for (_, source) in dispatchTimers {
            source.cancel()
        }
        dispatchTimers.removeAll()
        entries.removeAll()
        pomodoroEntryID = nil
        pomodoroState.reset()
        updateAmbient()
        clearPersisted()
    }

    public func retryPersistence() {
        switch persistenceIssue {
        case .loadFailed: restoreOrResumeTimers()
        case .saveFailed: persist()
        case .clearFailed: clearPersisted()
        case nil: break
        }
    }

    public func startPomodoro() {
        if let old = pomodoroEntryID { removeTimer(id: old) }
        pomodoroState.reset()
        addTimer(
            label: pomodoroState.currentPhaseLabel,
            duration: pomodoroState.currentPhaseDuration(settings: settings)
        )
        guard let entry = entries.last else { return }
        pomodoroEntryID = entry.id
        startEntry(entry.id)
    }

    // MARK: — Timer lifecycle

    private func startEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard !entries[index].isRunning else { return }
        entries[index].isRunning = true
        entries[index].isPaused = false
        entries[index].scheduledEndDate = Date().addingTimeInterval(entries[index].remaining)
        requestNotificationPermissionIfNeeded()
        scheduleDispatchTimer(for: id)
        updateAmbient()
        persist()
    }

    private func pauseEntry(_ id: UUID) {
        guard entries.contains(where: { $0.id == id && $0.isRunning }) else { return }
        synchronizeTimer(id: id, now: Date())
        guard let index = entries.firstIndex(where: { $0.id == id }), entries[index].isRunning else { return }
        entries[index].isRunning = false
        entries[index].isPaused = true
        entries[index].scheduledEndDate = nil
        stopDispatchTimer(for: id)
        updateAmbient()
        persist()
    }

    private func stopEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isRunning = false
        entries[index].isPaused = false
        entries[index].remaining = 0
        entries[index].scheduledEndDate = nil
        stopDispatchTimer(for: id)
        updateAmbient()
        persist()
    }

    private func resetEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        stopDispatchTimer(for: id)
        entries[index].isRunning = false
        entries[index].isPaused = false
        entries[index].remaining = entries[index].duration
        entries[index].scheduledEndDate = nil
        updateAmbient()
        persist()
    }

    private func updateAmbient() {
        guard isStarted else {
            onAmbientUpdate?(nil)
            return
        }
        if let running = entries.first(where: { $0.isRunning }) {
            let progress = running.duration > 0 ? running.remaining / running.duration : 0
            onAmbientUpdate?(.init(
                kind: .timer(label: remainingLabel(running.remaining), progress: progress),
                accentColor: settings.hudAccentColor
            ))
        } else {
            onAmbientUpdate?(nil)
        }
    }

    /// Décompte vivant « m:ss » affiché dans la pill ambient (mis à jour à chaque tick).
    private func remainingLabel(_ remaining: TimeInterval) -> String {
        let total = max(0, Int(remaining))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: — DispatchSourceTimer

    private func scheduleDispatchTimer(for id: UUID) {
        stopDispatchTimer(for: id)
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1.0)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { self.synchronizeTimer(id: id, now: Date()) }
        }
        source.resume()
        dispatchTimers[id] = source
    }

    private func stopDispatchTimer(for id: UUID) {
        dispatchTimers[id]?.cancel()
        dispatchTimers.removeValue(forKey: id)
    }

    /// Recalcule depuis une échéance absolue : la veille du Mac ne ralentit pas le minuteur.
    func synchronizeTimer(id: UUID, now: Date) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard entries[index].isRunning, let endDate = entries[index].scheduledEndDate else { return }
        entries[index].remaining = ceil(max(0, endDate.timeIntervalSince(now)))
        if entries[index].remaining <= 0 {
            entries[index].remaining = 0
            entries[index].isRunning = false
            entries[index].scheduledEndDate = nil
            stopDispatchTimer(for: id)
            sendFinishedNotification(for: entries[index])
            onFinished?()
            if id == pomodoroEntryID {
                advancePomodoro()
            } else {
                updateAmbient()
                persist()
            }
        } else {
            updateAmbient()
        }
    }

    private func advancePomodoro() {
        entries.removeAll { $0.id == pomodoroEntryID }
        pomodoroEntryID = nil
        pomodoroState.advance()
        addTimer(
            label: pomodoroState.currentPhaseLabel,
            duration: pomodoroState.currentPhaseDuration(settings: settings)
        )
        guard let entry = entries.last else { return }
        pomodoroEntryID = entry.id
        startEntry(entry.id)
    }

    // MARK: — Persistance (doc 13, Jalon 3, item 19)

    /// Recharge les timers laissés actifs par une session précédente. Les timers en cours
    /// reprennent leur `DispatchSourceTimer` et sont immédiatement resynchronisés : si
    /// l'échéance est déjà passée pendant que Ledge était fermé, `synchronizeTimer` les termine
    /// tout de suite (notification comprise) au lieu de les afficher figés à 0 sans réagir.
    private func restoreOrResumeTimers() {
        if entries.isEmpty {
            do {
                let state = try persistenceStore.load()
                persistenceIssue = nil
                if !state.entries.isEmpty {
                    entries = state.entries
                    pomodoroEntryID = state.pomodoroEntryID
                    pomodoroState = state.pomodoroState
                }
            } catch {
                persistenceIssue = .loadFailed
            }
        }
        let now = Date()
        for entry in entries where entry.isRunning {
            scheduleDispatchTimer(for: entry.id)
            synchronizeTimer(id: entry.id, now: now)
        }
        updateAmbient()
    }

    private func persist() {
        let state = PersistedTimerState(
            entries: entries, pomodoroEntryID: pomodoroEntryID, pomodoroState: pomodoroState
        )
        do {
            try persistenceStore.save(state)
            persistenceIssue = nil
        } catch {
            persistenceIssue = .saveFailed
        }
    }

    private func clearPersisted() {
        do {
            try persistenceStore.clear()
            persistenceIssue = nil
        } catch {
            persistenceIssue = .clearFailed
        }
    }

    // MARK: — Notifications

    private func requestNotificationPermissionIfNeeded() {
        guard !didRequestNotificationPermission,
              !settings.timerAlertVisualOnly,
              Bundle.main.bundlePath.hasSuffix(".app")
        else { return }
        didRequestNotificationPermission = true
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    private func sendFinishedNotification(for entry: TimerEntry) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }
        if settings.timerAlertVisualOnly { return }
        let content = UNMutableNotificationContent()
        content.title = entry.label
        content.body = NSLocalizedString("timer.notification.body", bundle: localizationBundle, comment: "")
        if !settings.timerSoundEnabled {
            content.sound = nil
        } else {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: entry.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

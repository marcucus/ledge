@testable import TimerModule
import Core
import Foundation
import Testing

@MainActor
struct TimerModuleTests {
    /// Répertoire temporaire isolé : ces tests ne doivent jamais toucher le vrai
    /// `Application Support/Ledge` de la machine (timers réels de l'utilisateur), même
    /// indirectement via les appels à `persist()` déclenchés par `addAndStart`/`send` (doc 13,
    /// Jalon 3, item 19).
    private static func makeIsolatedModule() -> (module: TimerModule, cleanup: () -> Void) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        let module = TimerModule(persistenceStore: TimerPersistenceStore(directory: dir))
        return (module, { try? FileManager.default.removeItem(at: dir) })
    }

    @Test func timerUsesAbsoluteDeadlineAfterLongPause() {
        let (module, cleanup) = Self.makeIsolatedModule()
        defer { cleanup() }
        guard let id = module.addAndStart(label: "Test", duration: 120),
              let endDate = module.entries.first?.scheduledEndDate
        else {
            Issue.record("Timer should start with an absolute deadline")
            return
        }

        module.synchronizeTimer(id: id, now: endDate.addingTimeInterval(-30))

        #expect(module.entries.first?.remaining == 30)
    }

    @Test func elapsedTimerFinishesImmediatelyAfterWake() {
        let (module, cleanup) = Self.makeIsolatedModule()
        defer { cleanup() }
        guard let id = module.addAndStart(label: "Test", duration: 60),
              let endDate = module.entries.first?.scheduledEndDate
        else {
            Issue.record("Timer should start with an absolute deadline")
            return
        }

        module.synchronizeTimer(id: id, now: endDate.addingTimeInterval(10))

        #expect(module.entries.first?.remaining == 0)
        #expect(module.entries.first?.isRunning == false)
    }

    // MARK: — Persistance (doc 13, Jalon 3, item 19)

    @Test func restartedModuleRestoresRunningTimerFromTheSameStore() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TimerPersistenceStore(directory: dir)

        let moduleA = TimerModule(persistenceStore: store)
        guard let id = moduleA.addAndStart(label: "Restored", duration: 300) else {
            Issue.record("Timer should start")
            return
        }

        // Simule un quit/relance : nouvelle instance du module, même stockage sur disque.
        let moduleB = TimerModule(persistenceStore: store)
        moduleB.start()

        #expect(moduleB.entries.first?.id == id)
        #expect(moduleB.entries.first?.isRunning == true)
    }

    @Test func restoredTimerAlreadyExpiredWhileQuitFinishesImmediately() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TimerPersistenceStore(directory: dir)

        var entry = TimerEntry(label: "Expired while quit", duration: 60)
        entry.isRunning = true
        entry.remaining = 60
        entry.scheduledEndDate = Date().addingTimeInterval(-30) // échéance déjà passée
        try store.save(PersistedTimerState(entries: [entry], pomodoroEntryID: nil, pomodoroState: PomodoroState()))

        let module = TimerModule(persistenceStore: store)
        module.start()

        #expect(module.entries.first?.isRunning == false)
        #expect(module.entries.first?.remaining == 0)
    }

    @Test func stopPreservesPersistedTimers() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TimerPersistenceStore(directory: dir)
        let moduleA = TimerModule(persistenceStore: store)
        moduleA.addAndStart(label: "Test", duration: 60)

        moduleA.stop()

        #expect(try store.load().entries.count == 1)
        let moduleB = TimerModule(persistenceStore: store)
        moduleB.start()
        #expect(moduleB.entries.count == 1)
    }

    @Test func explicitClearAllTimersRemovesPersistedTimers() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = TimerPersistenceStore(directory: dir)
        let module = TimerModule(persistenceStore: store)
        module.start()
        module.addAndStart(label: "Test", duration: 60)

        module.clearAllTimers()

        let restored = TimerModule(persistenceStore: store)
        restored.start()
        #expect(restored.entries.isEmpty)
    }

    @Test func appProfileTemporarilyDisablingTimersPreservesAndResumesThem() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let suiteName = "ledge.timer-profile.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.appProfiles = [
            AppProfile(bundleID: "com.example.focus", moduleOrder: [], disabledModuleIDs: ["timers"]),
        ]
        let store = TimerPersistenceStore(directory: dir)
        let module = TimerModule(persistenceStore: store)
        let controller = NotchController(settings: settings)
        controller.register(modules: [module])
        guard let id = module.addAndStart(label: "Preserved", duration: 300),
              let endDate = module.entries.first?.scheduledEndDate
        else {
            Issue.record("Timer should start")
            return
        }

        controller.updateActiveProfile(bundleID: "com.example.focus")
        #expect(module.entries.first?.id == id)
        #expect(try store.load().entries.first?.id == id)

        controller.updateActiveProfile(bundleID: nil)
        #expect(module.entries.first?.isRunning == true)
        #expect(module.entries.first?.scheduledEndDate == endDate)
    }

    @Test func progressAlwaysStaysInUnitRange() {
        var beforeStart = TimerEntry(label: "Before", duration: 10)
        beforeStart.remaining = 20
        var afterEnd = TimerEntry(label: "After", duration: 10)
        afterEnd.remaining = -5

        #expect(beforeStart.progress == 0)
        #expect(afterEnd.progress == 1)
    }
}

@testable import Core
import Foundation
import SwiftUI
import Testing

@MainActor
struct NotchControllerTests {
    private final class StubModule: NotchModule {
        let id: String
        let tabIcon = "circle"
        let tabLabel: LocalizedStringKey = "stub"
        private(set) var startCount = 0
        private(set) var stopCount = 0
        /// Vrai entre un `start()` et le `stop()` suivant — reflète le cycle de vie réel
        /// attendu du Jalon 2 (un module désactivé doit être arrêté, pas seulement caché).
        var isRunning: Bool { startCount > stopCount }

        init(id: String) {
            self.id = id
        }

        func start() { startCount += 1 }
        func stop() { stopCount += 1 }
    }

    /// Réglages isolés par test — évite de lire/écrire dans les vrais UserDefaults de l'utilisateur.
    /// `UserDefaults(suiteName:)` persiste sur disque : le suite est supprimé via le `cleanup`
    /// retourné, à appeler en `defer` dans chaque test.
    private static func makeController() -> (controller: NotchController, cleanup: () -> Void) {
        let suiteName = "ledge.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("UserDefaults(suiteName:) returned nil for test suite \(suiteName)")
        }
        let controller = NotchController(settings: SettingsStore(defaults: defaults))
        return (controller, { UserDefaults.standard.removePersistentDomain(forName: suiteName) })
    }

    private static func eventually(
        timeout: Duration = .seconds(1),
        condition: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if condition() { return true }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }

    // MARK: — Ambient : priorité

    @Test func ambientHigherPriorityWins() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        let low = AmbientContent(kind: .dropzone(count: 1))
        let high = AmbientContent(kind: .timer(label: "5:00", progress: 0.5))

        controller.setAmbient(low, sourceID: "dropzone", priority: 1)
        controller.setAmbient(high, sourceID: "timer", priority: 2)

        guard case .timer = controller.ambientContent?.kind else {
            Issue.record("expected timer content to win on priority")
            return
        }
    }

    @Test func ambientFallsBackWhenHighestPriorityRemoved() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        let low = AmbientContent(kind: .dropzone(count: 1))
        let high = AmbientContent(kind: .timer(label: "5:00", progress: 0.5))

        controller.setAmbient(low, sourceID: "dropzone", priority: 1)
        controller.setAmbient(high, sourceID: "timer", priority: 2)
        controller.setAmbient(nil, sourceID: "timer", priority: 2)

        guard case .dropzone = controller.ambientContent?.kind else {
            Issue.record("expected dropzone content after removing the higher-priority source")
            return
        }
    }

    @Test func ambientNilWhenAllSourcesCleared() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        let content = AmbientContent(kind: .dropzone(count: 1))
        controller.setAmbient(content, sourceID: "dropzone", priority: 1)
        controller.setAmbient(nil, sourceID: "dropzone", priority: 1)
        #expect(controller.ambientContent == nil)
    }

    @Test func settingAmbientFromCollapsedTransitionsToAmbientState() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        #expect(controller.state == .collapsed)
        controller.setAmbient(AmbientContent(kind: .dropzone(count: 1)), sourceID: "dropzone", priority: 1)
        #expect(controller.state == .ambient)
    }

    // MARK: — HUD

    @Test func showHUDFromCollapsedTransitionsToHUDState() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.showHUD(HUDContent(kind: .volume, value: 0.5))
        #expect(controller.state == .hud)
        #expect(controller.hudContent != nil)
    }

    @Test func showHUDIsIgnoredWhileExpanded() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.cursorEntered()
        #expect(controller.state == .expanded)
        controller.showHUD(HUDContent(kind: .volume, value: 0.5))
        #expect(controller.state == .expanded)
        #expect(controller.hudContent == nil)
    }

    // MARK: — Peek de fin de minuteur (doc 13, Jalon 3, item 20)

    @Test func showPeekSelectsModuleAndTransitionsToPeeking() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.register(modules: [StubModule(id: "timers")])

        controller.showPeek(selecting: "timers", duration: 5)

        #expect(controller.state == .peeking)
        #expect(controller.selectedModuleID == "timers")
    }

    @Test func showPeekIsIgnoredWhileExpanded() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.register(modules: [StubModule(id: "timers"), StubModule(id: "media")])
        controller.selectModule(id: "media")
        controller.cursorEntered()
        #expect(controller.state == .expanded)

        controller.showPeek(selecting: "timers", duration: 5)

        #expect(controller.state == .expanded)
        #expect(controller.selectedModuleID == "media")
    }

    @Test func showPeekIsIgnoredForUnknownModule() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.register(modules: [StubModule(id: "timers")])

        controller.showPeek(selecting: "does-not-exist", duration: 5)

        #expect(controller.state == .collapsed)
    }

    @Test func showPeekAutoCollapsesAfterDuration() async {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.register(modules: [StubModule(id: "timers")])

        controller.showPeek(selecting: "timers", duration: 0.01)
        #expect(controller.state == .peeking)

        #expect(await Self.eventually { controller.state == .collapsed })
    }

    // MARK: — Clic panneau

    @Test func panelClickedExpandsByDefault() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.panelClicked()
        #expect(controller.state == .expanded)
    }

    @Test func hoverExpandsImmediatelyWithoutPeeking() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }

        controller.cursorEntered()

        #expect(controller.state == .expanded)
    }

    @Test func panelClickedTogglesClosed() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.panelClicked()
        #expect(controller.state == .expanded)
        controller.panelClicked()
        #expect(controller.state == .collapsed)
    }

    @Test func expandedContentWaitsForWindowAnimation() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }

        controller.cursorEntered()
        #expect(controller.state == .expanded)
        #expect(!controller.isExpansionSettled)

        controller.expansionDidFinish()
        #expect(controller.isExpansionSettled)

        controller.dismiss()
        #expect(controller.isExpansionSettled)
    }

    @Test func dismissReturnsToAmbientWhenAmbientContentActive() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.setAmbient(AmbientContent(kind: .dropzone(count: 1)), sourceID: "dropzone", priority: 1)
        controller.cursorEntered()
        #expect(controller.state == .expanded)
        controller.dismiss()
        #expect(controller.state == .ambient)
    }

    @Test func accessibleFullscreenSuppressesAmbientUntilLeavingFullscreen() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.setAmbient(AmbientContent(kind: .dropzone(count: 1)), sourceID: "dropzone", priority: 1)
        #expect(controller.state == .ambient)

        controller.updateFullscreenStatus(isActive: true)
        #expect(controller.state == .collapsed)

        controller.updateFullscreenStatus(isActive: false)
        #expect(controller.state == .ambient)
    }

    @Test func timerRingExposesElapsedProgress() {
        let suiteName = "ledge.timer-ring.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.showRingWhenTimerActive = true
        let controller = NotchController(settings: settings)

        controller.setAmbient(
            AmbientContent(kind: .timer(label: "5:00", progress: 0.75)),
            sourceID: "timers",
            priority: 2
        )

        #expect(controller.timerRingActive)
        #expect(controller.timerRingProgress == 0.25)
        #expect(controller.state == .collapsed)
    }

    @Test func fullscreenDetectorIgnoresOrdinaryWindowsAndFindsCoveringWindow() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let ordinary = FullscreenMonitor.WindowSnapshot(
            ownerPID: 42,
            layer: 0,
            alpha: 1,
            bounds: CGRect(x: 0, y: 24, width: 1512, height: 930)
        )
        let fullscreen = FullscreenMonitor.WindowSnapshot(
            ownerPID: 42,
            layer: 0,
            alpha: 1,
            bounds: screen
        )

        #expect(!FullscreenMonitor.isFullscreen(screenBounds: screen, frontmostPID: 42, windows: [ordinary]))
        #expect(FullscreenMonitor.isFullscreen(screenBounds: screen, frontmostPID: 42, windows: [fullscreen]))
        #expect(!FullscreenMonitor.isFullscreen(screenBounds: screen, frontmostPID: 7, windows: [fullscreen]))
    }

    @Test func focusedAndImmersiveKeepDistinctExpandedGeometry() {
        let suiteName = "ledge.composition-geometry.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        let controller = NotchController(settings: settings)

        settings.panelComposition = .focused
        #expect(controller.expandedWidth == 580)
        #expect(controller.expandedContentHeight == 200)

        settings.panelComposition = .immersive
        #expect(controller.expandedWidth == 744)
        #expect(controller.expandedContentHeight == 320)
    }

    @Test func transientPopoverInteractionSuspendsAutomaticCollapse() async {
        let suiteName = "ledge.transient-interaction.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.collapseDelay = 0.01
        let controller = NotchController(settings: settings)

        controller.cursorEntered()
        controller.setTransientInteractionActive(true)
        controller.cursorExited()
        try? await Task.sleep(for: .milliseconds(30))
        #expect(controller.state == .expanded)

        controller.setTransientInteractionActive(false)
        #expect(await Self.eventually { controller.state == .collapsed })
    }

    @Test func hidingSelectedModuleFallsBackToAvailableContent() {
        let suiteName = "ledge.hidden-selection.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.panelComposition = .focused
        let controller = NotchController(settings: settings)
        controller.register(modules: [StubModule(id: "media"), StubModule(id: "timers")])
        controller.selectModule(id: "timers")
        #expect(controller.activeModuleID == "timers")

        settings.setModulePlacement(.hidden, for: "timers", in: .focused)

        #expect(controller.activeModuleID == "media")
        #expect(controller.selectedModule?.id == "media")
    }

    @Test func gridButtonDisappearsWhenGridHasNoModules() {
        let suiteName = "ledge.empty-grid.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.panelComposition = .focused
        settings.setShowsModuleGrid(true, in: .focused)
        settings.setModulePlacement(.bar, for: "media", in: .focused)
        settings.setModulePlacement(.hidden, for: "timers", in: .focused)
        let controller = NotchController(settings: settings)
        controller.register(modules: [StubModule(id: "media"), StubModule(id: "timers")])

        #expect(controller.gridModules.isEmpty)
        #expect(!controller.showsModuleGrid)
    }

    // MARK: — Cycle de vie des modules (Jalon 2 : visible / enabled / profils d'app)

    @Test func registerOnlyStartsModulesEnabledInSettings() {
        let suiteName = "ledge.module-lifecycle-register.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.setModule("clipboard", enabled: false)
        let controller = NotchController(settings: settings)
        let media = StubModule(id: "media")
        let clipboard = StubModule(id: "clipboard")

        controller.register(modules: [media, clipboard])

        #expect(media.isRunning)
        #expect(!clipboard.isRunning)
        #expect(clipboard.startCount == 0)
    }

    @Test func disablingAModuleStopsItAndReenablingRestartsIt() async {
        let suiteName = "ledge.module-lifecycle-toggle.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        let controller = NotchController(settings: settings)
        let clipboard = StubModule(id: "clipboard")
        controller.register(modules: [clipboard])
        #expect(clipboard.isRunning)

        // Confidentialité (point 9) : désactiver le module doit réellement l'arrêter, pas
        // seulement le masquer de la navigation — c'est exactement le bug du presse-papiers
        // signalé par docs/13-audit-finalisation.md.
        settings.setModule("clipboard", enabled: false)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(!clipboard.isRunning)

        settings.setModule("clipboard", enabled: true)
        try? await Task.sleep(for: .milliseconds(30))
        #expect(clipboard.isRunning)
        #expect(clipboard.startCount == 2)
        #expect(clipboard.stopCount == 1)
    }

    @Test func appProfileDisablingAModuleStopsItWhileActiveAndRestartsWhenLeft() {
        let suiteName = "ledge.module-lifecycle-profile.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let settings = SettingsStore(defaults: defaults)
        settings.appProfiles = [
            AppProfile(bundleID: "com.example.banking", moduleOrder: ["media"], disabledModuleIDs: ["clipboard"]),
        ]
        let controller = NotchController(settings: settings)
        let clipboard = StubModule(id: "clipboard")
        controller.register(modules: [clipboard])
        #expect(clipboard.isRunning)

        // `updateActiveProfile` applique l'activation directement (pas de propriété observable
        // de SettingsStore ne change ici) : pas besoin d'attendre un cycle du run loop.
        controller.updateActiveProfile(bundleID: "com.example.banking")
        #expect(!clipboard.isRunning)

        controller.updateActiveProfile(bundleID: nil)
        #expect(clipboard.isRunning)
    }

    @Test func globallyDisabledDropZoneCannotOpenOrSelectPanelDuringFileDrag() {
        let suiteName = "ledge.dropzone-global-disable.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.setModule("dropzone", enabled: false)
        let controller = NotchController(settings: settings)
        let media = StubModule(id: "media")
        let dropzone = StubModule(id: "dropzone")
        var dragUpdates: [Bool] = []
        controller.onDragHoverChange = { dragUpdates.append($0) }
        controller.register(modules: [media, dropzone])

        controller.dragApproachNotch(preferredModuleID: "dropzone")

        #expect(controller.state == .collapsed)
        #expect(controller.activeModuleID == "media")
        #expect(dragUpdates.isEmpty)
    }

    @Test func profileDisabledDropZoneCannotOpenOrSelectPanelDuringFileDrag() {
        let suiteName = "ledge.dropzone-profile-disable.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.appProfiles = [
            AppProfile(bundleID: "com.example.editor", moduleOrder: ["media"], disabledModuleIDs: ["dropzone"]),
        ]
        let controller = NotchController(settings: settings)
        let media = StubModule(id: "media")
        let dropzone = StubModule(id: "dropzone")
        var dragUpdates: [Bool] = []
        controller.onDragHoverChange = { dragUpdates.append($0) }
        controller.register(modules: [media, dropzone])
        controller.updateActiveProfile(bundleID: "com.example.editor")

        controller.dragApproachNotch(preferredModuleID: "dropzone")

        #expect(controller.state == .collapsed)
        #expect(controller.activeModuleID == "media")
        #expect(dragUpdates.isEmpty)
    }
}

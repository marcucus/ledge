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

        init(id: String) {
            self.id = id
        }

        func start() {}
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

    // MARK: — Clic panneau

    @Test func panelClickedExpandsByDefault() {
        let (controller, cleanup) = Self.makeController()
        defer { cleanup() }
        controller.panelClicked()
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
        try? await Task.sleep(for: .milliseconds(30))
        #expect(controller.state == .collapsed)
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
}

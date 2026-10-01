@testable import Core
import Foundation
import Testing

struct SettingsStoreTests {
    @Test func onboardingStartsIncompleteAndPersistsCompletion() {
        let suiteName = "ledge.settings.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let initialStore = SettingsStore(defaults: defaults)
        #expect(!initialStore.hasCompletedOnboarding)

        initialStore.hasCompletedOnboarding = true

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(reloadedStore.hasCompletedOnboarding)
    }

    @Test func targetScreenSelectionPersistsIdentifierAndName() {
        let suiteName = "ledge.screen.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let initialStore = SettingsStore(defaults: defaults)
        initialStore.targetScreenIdentifier = "E9DBA2F0-TEST"
        initialStore.targetScreenName = "Studio Display"

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(reloadedStore.targetScreenIdentifier == "E9DBA2F0-TEST")
        #expect(reloadedStore.targetScreenName == "Studio Display")
    }

    @Test func multiDisplaySelectionPersistsModeIdentifiersAndNames() {
        let suiteName = "ledge.multi-screen.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let initialStore = SettingsStore(defaults: defaults)
        initialStore.displayTargetMode = .selected
        initialStore.selectedScreenIdentifiers = ["one", "two"]
        initialStore.selectedScreenNames = ["one": "Mac", "two": "Studio"]

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(reloadedStore.displayTargetMode == .selected)
        #expect(reloadedStore.selectedScreenIdentifiers == ["one", "two"])
        #expect(reloadedStore.selectedScreenNames["two"] == "Studio")
    }

    @Test func panelCompositionDefaultsToPanoramicAndPersists() {
        let suiteName = "ledge.composition.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let initialStore = SettingsStore(defaults: defaults)
        #expect(initialStore.panelComposition == .panoramic)

        initialStore.panelComposition = .immersive

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(reloadedStore.panelComposition == .immersive)
    }

    @Test func hotZoneDefaultsToStandardAndPersists() {
        let suiteName = "ledge.hot-zone.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let initialStore = SettingsStore(defaults: defaults)
        #expect(initialStore.hotZoneSize == .standard)

        initialStore.hotZoneSize = .generous

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(reloadedStore.hotZoneSize == .generous)
    }

    @Test func modulePlacementsAreIndependentForEachComposition() {
        let suiteName = "ledge.module-placement.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)

        #expect(store.showsModuleGrid(in: .focused))
        #expect(store.modulePlacement("media", in: .focused) == .bar)
        #expect(store.modulePlacement("dropzone", in: .focused) == .grid)

        #expect(!store.showsModuleGrid(in: .panoramic))
        #expect(store.modulePlacement("notes", in: .panoramic) == .bar)

        #expect(store.showsModuleGrid(in: .immersive))
        #expect(store.modulePlacement("calendar", in: .immersive) == .bar)
        #expect(store.modulePlacement("notes", in: .immersive) == .grid)

        store.setShowsModuleGrid(false, in: .focused)
        store.setModulePlacement(.hidden, for: "media", in: .focused)
        store.setModulePlacement(.bar, for: "notes", in: .focused)
        store.moveModule("notes", by: -1, in: .focused)

        #expect(!store.showsModuleGrid(in: .focused))
        #expect(store.modulePlacement("media", in: .focused) == .hidden)
        #expect(store.modulePlacement("notes", in: .focused) == .bar)
        #expect(store.modulePlacement("media", in: .panoramic) == .bar)
        #expect((store.moduleOrder(in: .focused).firstIndex(of: "notes") ?? .max)
                < (store.moduleOrder(in: .focused).firstIndex(of: "timers") ?? .max))
        #expect(store.moduleOrder(in: .panoramic).first == "media")

        let restoredStore = SettingsStore(defaults: defaults)
        #expect(!restoredStore.showsModuleGrid(in: .focused))
        #expect(restoredStore.modulePlacement("media", in: .focused) == .hidden)
        #expect(restoredStore.modulePlacement("notes", in: .focused) == .bar)
        #expect((restoredStore.moduleOrder(in: .focused).firstIndex(of: "notes") ?? .max)
                < (restoredStore.moduleOrder(in: .focused).firstIndex(of: "timers") ?? .max))
    }

    // doc 13, Jalon 4, item 27 : réinitialisation des réglages.
    @Test func resetToDefaultsRestoresDefaultValuesAndPersistsThem() {
        let suiteName = "ledge.reset.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(defaults: defaults)
        store.hasCompletedOnboarding = true
        store.collapseDelay = 1.4
        store.hotZoneSize = .generous
        store.clipboardMaxItems = 200
        store.clipboardExcludedApps = ["com.example.app"]
        store.setModule("clipboard", enabled: false)
        store.appProfiles = [
            AppProfile(bundleID: "com.example.app", moduleOrder: ["media"], disabledModuleIDs: ["media"]),
        ]

        store.resetToDefaults()

        #expect(!store.hasCompletedOnboarding)
        #expect(store.collapseDelay == 0.6)
        #expect(store.hotZoneSize == .standard)
        #expect(store.clipboardMaxItems == 50)
        #expect(store.clipboardExcludedApps.isEmpty)
        #expect(store.isModuleEnabled("clipboard"))
        #expect(store.appProfiles.isEmpty)

        let reloadedStore = SettingsStore(defaults: defaults)
        #expect(!reloadedStore.hasCompletedOnboarding)
        #expect(reloadedStore.collapseDelay == 0.6)
        #expect(reloadedStore.clipboardExcludedApps.isEmpty)
        #expect(reloadedStore.isModuleEnabled("clipboard"))
        #expect(reloadedStore.appProfiles.isEmpty)
    }
}

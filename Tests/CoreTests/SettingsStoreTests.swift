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
}

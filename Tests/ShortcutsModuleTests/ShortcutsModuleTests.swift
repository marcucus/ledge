@testable import ShortcutsModule
import Foundation
import Testing

private actor StubShortcutsCommandRunner: ShortcutsCommandRunning {
    private var responses: [String?]
    private let delay: Duration?
    private(set) var calls: [[String]] = []

    init(responses: [String?], delay: Duration? = nil) {
        self.responses = responses
        self.delay = delay
    }

    func output(arguments: [String]) async -> String? {
        calls.append(arguments)
        if let delay { try? await Task.sleep(for: delay) }
        guard !responses.isEmpty else { return nil }
        return responses.removeFirst()
    }
}

@MainActor
private func eventually(
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

@MainActor
struct ShortcutsModuleTests {
    @Test func favoritesPersistAndAreOrderedFirst() async {
        let suiteName = "ledge.shortcuts.favorites.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let runner = StubShortcutsCommandRunner(responses: ["First\nFavorite\nLast\n"])
        let module = ShortcutsModule(commandRunner: runner, defaults: defaults)
        module.start()
        #expect(await eventually { module.shortcuts.count == 3 })

        module.toggleFavorite("Favorite")

        #expect(module.orderedShortcuts == ["Favorite", "First", "Last"])
        let reloaded = ShortcutsModule(commandRunner: runner, defaults: defaults)
        #expect(reloaded.isFavorite("Favorite"))
    }

    @Test func startLoadsAndNormalizesShortcutNames() async {
        let runner = StubShortcutsCommandRunner(responses: [" Morning \n\nFocus\n"])
        let module = ShortcutsModule(commandRunner: runner)

        module.start()

        #expect(await eventually { module.shortcuts == ["Morning", "Focus"] })
        #expect(!module.loadFailed)
        #expect(await runner.calls == [["list"]])
    }

    @Test func listFailureIsVisible() async {
        let runner = StubShortcutsCommandRunner(responses: [nil])
        let module = ShortcutsModule(commandRunner: runner)

        module.start()

        #expect(await eventually { module.loadFailed })
        #expect(!module.isLoading)
    }

    @Test func runUsesExactShortcutNameAndReportsFailure() async {
        let runner = StubShortcutsCommandRunner(responses: ["One\n", nil])
        let module = ShortcutsModule(commandRunner: runner)
        module.start()
        #expect(await eventually { module.shortcuts == ["One"] })

        module.run("One")

        #expect(await eventually { module.lastRunFailedName == "One" })
        #expect(await runner.calls == [["list"], ["run", "One"]])
    }

    @Test func successfulRunExposesTransientFeedback() async {
        let runner = StubShortcutsCommandRunner(responses: ["One\n", ""])
        let module = ShortcutsModule(commandRunner: runner)
        module.start()
        #expect(await eventually { module.shortcuts == ["One"] })

        module.run("One")

        #expect(await eventually { module.lastRunSucceededName == "One" })
        #expect(module.lastRunFailedName == nil)
    }

    @Test func stopInvalidatesPendingListResult() async {
        let runner = StubShortcutsCommandRunner(responses: ["Late\n"], delay: .milliseconds(50))
        let module = ShortcutsModule(commandRunner: runner)

        module.start()
        module.stop()
        try? await Task.sleep(for: .milliseconds(80))

        #expect(module.shortcuts.isEmpty)
        #expect(!module.isLoading)
    }
}

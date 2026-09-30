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
struct ShortcutsModuleTests {
    @Test func startLoadsAndNormalizesShortcutNames() async {
        let runner = StubShortcutsCommandRunner(responses: [" Morning \n\nFocus\n"])
        let module = ShortcutsModule(commandRunner: runner)

        module.start()
        try? await Task.sleep(for: .milliseconds(30))

        #expect(module.shortcuts == ["Morning", "Focus"])
        #expect(!module.loadFailed)
        #expect(await runner.calls == [["list"]])
    }

    @Test func listFailureIsVisible() async {
        let runner = StubShortcutsCommandRunner(responses: [nil])
        let module = ShortcutsModule(commandRunner: runner)

        module.start()
        try? await Task.sleep(for: .milliseconds(30))

        #expect(module.loadFailed)
        #expect(!module.isLoading)
    }

    @Test func runUsesExactShortcutNameAndReportsFailure() async {
        let runner = StubShortcutsCommandRunner(responses: ["One\n", nil])
        let module = ShortcutsModule(commandRunner: runner)
        module.start()
        try? await Task.sleep(for: .milliseconds(30))

        module.run("One")
        try? await Task.sleep(for: .milliseconds(30))

        #expect(module.lastRunFailedName == "One")
        #expect(await runner.calls == [["list"], ["run", "One"]])
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

@testable import Core
import Testing

struct DisplayTargetSelectionTests {
    @Test func automaticUsesSingleImplicitTarget() {
        let targets = DisplayTargetSelection.resolvedIdentifiers(
            mode: .automatic,
            selectedIdentifiers: ["external"],
            availableIdentifiers: ["built-in", "external"]
        )

        #expect(targets.count == 1)
        #expect(targets[0] == nil)
    }

    @Test func allUsesEveryConnectedDisplay() {
        let targets = DisplayTargetSelection.resolvedIdentifiers(
            mode: .all,
            selectedIdentifiers: [],
            availableIdentifiers: ["built-in", "external"]
        )

        #expect(targets.compactMap { $0 } == ["built-in", "external"])
    }

    @Test func selectedKeepsConnectedChoicesAndFallsBackWhenNoneAreAvailable() {
        let connected = DisplayTargetSelection.resolvedIdentifiers(
            mode: .selected,
            selectedIdentifiers: ["external", "offline"],
            availableIdentifiers: ["built-in", "external"]
        )
        let fallback = DisplayTargetSelection.resolvedIdentifiers(
            mode: .selected,
            selectedIdentifiers: ["offline"],
            availableIdentifiers: ["built-in"]
        )

        #expect(connected.compactMap { $0 } == ["external"])
        #expect(fallback.count == 1)
        #expect(fallback[0] == nil)
    }
}


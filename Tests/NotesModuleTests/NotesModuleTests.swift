@testable import NotesModule
import Foundation
import Testing

@MainActor
struct NotesModuleTests {
    @Test func startLoadsPersistedNote() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        defaults.set("Persisted", forKey: "notesText")
        let module = NotesModule(defaults: defaults)

        module.start()

        #expect(module.text == "Persisted")
    }

    @Test func editingTextSavesImmediately() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        let module = NotesModule(defaults: defaults)

        module.text = "New note"

        #expect(defaults.string(forKey: "notesText") == "New note")
    }

    @Test func clearRemovesMemoryAndPersistence() {
        let (defaults, cleanup) = makeDefaults()
        defer { cleanup() }
        let module = NotesModule(defaults: defaults)
        module.text = "Temporary"

        module.clear()

        #expect(module.text.isEmpty)
        #expect(defaults.object(forKey: "notesText") == nil)
    }

    private func makeDefaults() -> (UserDefaults, () -> Void) {
        let suiteName = "ledge.notes.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Unable to create isolated UserDefaults suite")
        }
        return (defaults, { UserDefaults.standard.removePersistentDomain(forName: suiteName) })
    }
}

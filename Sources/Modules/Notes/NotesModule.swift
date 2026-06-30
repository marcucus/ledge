import Core
import Foundation
import SwiftUI

// MARK: — NotesModule

/// Simple free-text note module — no Messages access, no extraction logic,
/// just a single string the user types and can clear manually.
@MainActor
@Observable
public final class NotesModule: NotchModule {
    public let id = "notes"

    /// Current note text, persisted to `UserDefaults` on every change.
    public var text: String = "" {
        didSet {
            guard text != oldValue else { return }
            save()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: — NotchModule

    public func start() {
        text = defaults.string(forKey: Keys.text) ?? ""
    }

    // MARK: — Public API

    /// Saves the current text to `UserDefaults`.
    func save() {
        defaults.set(text, forKey: Keys.text)
    }

    /// Clears the note, in memory and in persisted storage.
    public func clear() {
        text = ""
        defaults.removeObject(forKey: Keys.text)
    }

    // MARK: — Keys

    private enum Keys {
        static let text = "notesText"
    }
}

// MARK: — NotchModule protocol conformance

public extension NotesModule {
    var tabIcon: String {
        "note.text"
    }

    var tabLabel: LocalizedStringKey {
        "module.notes.label"
    }

    func makePeekView() -> AnyView {
        AnyView(NotesPeekView(module: self))
    }

    func makeContentView() -> AnyView {
        AnyView(NotesContentView(module: self))
    }
}

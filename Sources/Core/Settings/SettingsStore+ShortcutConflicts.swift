import Foundation

public extension SettingsStore {
    func setGlobalShortcutConflict(id: String, isConflicted: Bool) {
        if isConflicted {
            globalShortcutConflictIDs.insert(id)
        } else {
            globalShortcutConflictIDs.remove(id)
        }
    }

    func clearGlobalShortcutConflicts() {
        globalShortcutConflictIDs.removeAll()
    }
}

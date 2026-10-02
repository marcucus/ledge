import Foundation

/// Instantané persistable de l'état du module Timer.
struct PersistedTimerState: Codable {
    var entries: [TimerEntry]
    var pomodoroEntryID: UUID?
    var pomodoroState: PomodoroState

    static let empty = Self(entries: [], pomodoroEntryID: nil, pomodoroState: PomodoroState())
}

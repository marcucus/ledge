import Core
import Foundation

public struct PomodoroState: Codable {
    public enum Phase: Codable { case work, shortBreak, longBreak }
    public var phase: Phase = .work
    public var completedWorkSessions = 0

    public var currentPhaseLabel: String {
        switch phase {
        case .work: "Pomodoro"
        case .shortBreak: NSLocalizedString("timer.pomodoro.shortBreak", bundle: localizationBundle, comment: "")
        case .longBreak: NSLocalizedString("timer.pomodoro.longBreak", bundle: localizationBundle, comment: "")
        }
    }

    public func currentPhaseDuration(settings: SettingsStore) -> TimeInterval {
        switch phase {
        case .work: return settings.pomodoroWorkDuration * 60
        case .shortBreak: return settings.pomodoroShortBreakDuration * 60
        case .longBreak: return settings.pomodoroLongBreakDuration * 60
        }
    }

    public mutating func reset() {
        phase = .work
        completedWorkSessions = 0
    }

    public mutating func advance() {
        switch phase {
        case .work:
            completedWorkSessions += 1
            phase = completedWorkSessions % 4 == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            phase = .work
        }
    }
}

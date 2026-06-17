import Core
import Foundation
import SwiftUI
import UserNotifications

public enum TimerAction {
    case start(id: UUID)
    case pause(id: UUID)
    case stop(id: UUID)
    case reset(id: UUID)
}

@MainActor
@Observable
public final class TimerModule: NotchModule {
    public let id = "timers"
    public let tabIcon = "timer"
    public let tabLabel: LocalizedStringKey = "module.timers.label"

    public private(set) var entries: [TimerEntry] = []
    public private(set) var pomodoroState: PomodoroState = .init()

    @ObservationIgnored private nonisolated(unsafe) var dispatchTimers: [UUID: DispatchSourceTimer] = [:]

    public init() {
        requestNotificationPermission()
    }

    // MARK: — NotchModule

    public func start() {}

    public func stop() {
        for (_, source) in dispatchTimers {
            source.cancel()
        }
        dispatchTimers.removeAll()
        entries.removeAll()
    }

    public func makePeekView() -> AnyView {
        AnyView(TimerPeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(TimerContentView(module: self))
    }

    deinit {
        for (_, source) in dispatchTimers {
            source.cancel()
        }
        dispatchTimers.removeAll()
    }

    // MARK: — Public API

    public func send(_ action: TimerAction) {
        switch action {
        case let .start(id): startEntry(id)
        case let .pause(id): pauseEntry(id)
        case let .stop(id): stopEntry(id)
        case let .reset(id): resetEntry(id)
        }
    }

    public func addTimer(label: String, duration: TimeInterval) {
        let entry = TimerEntry(label: label, duration: duration)
        entries.append(entry)
    }

    public func removeTimer(id: UUID) {
        stopDispatchTimer(for: id)
        entries.removeAll { $0.id == id }
    }

    public func startPomodoro() {
        pomodoroState.reset()
        let duration = pomodoroState.currentPhaseDuration
        addTimer(label: pomodoroState.currentPhaseLabel, duration: duration)
        guard let entry = entries.last else { return }
        startEntry(entry.id)
    }

    // MARK: — Timer lifecycle

    private func startEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard !entries[index].isRunning else { return }
        entries[index].isRunning = true
        entries[index].isPaused = false
        scheduleDispatchTimer(for: id)
    }

    private func pauseEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard entries[index].isRunning else { return }
        entries[index].isRunning = false
        entries[index].isPaused = true
        stopDispatchTimer(for: id)
    }

    private func stopEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isRunning = false
        entries[index].isPaused = false
        entries[index].remaining = 0
        stopDispatchTimer(for: id)
    }

    private func resetEntry(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        stopDispatchTimer(for: id)
        entries[index].isRunning = false
        entries[index].isPaused = false
        entries[index].remaining = entries[index].duration
    }

    // MARK: — DispatchSourceTimer

    private func scheduleDispatchTimer(for id: UUID) {
        stopDispatchTimer(for: id)
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now() + 1, repeating: 1.0)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { self.tick(id: id) }
        }
        source.resume()
        dispatchTimers[id] = source
    }

    private func stopDispatchTimer(for id: UUID) {
        dispatchTimers[id]?.cancel()
        dispatchTimers.removeValue(forKey: id)
    }

    private func tick(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].remaining -= 1
        if entries[index].remaining <= 0 {
            entries[index].remaining = 0
            entries[index].isRunning = false
            stopDispatchTimer(for: id)
            sendFinishedNotification(for: entries[index])
        }
    }

    // MARK: — Notifications

    private func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        Task {
            try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    private func sendFinishedNotification(for entry: TimerEntry) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = entry.label
        content.body = NSLocalizedString("timer.notification.body", bundle: localizationBundle, comment: "")
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: entry.id.uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: — Pomodoro

public struct PomodoroState {
    public enum Phase { case work, shortBreak, longBreak }
    public var phase: Phase = .work
    public var completedWorkSessions: Int = 0

    public var currentPhaseLabel: String {
        switch phase {
        case .work: "Pomodoro"
        case .shortBreak: NSLocalizedString("timer.pomodoro.shortBreak", bundle: localizationBundle, comment: "")
        case .longBreak: NSLocalizedString("timer.pomodoro.longBreak", bundle: localizationBundle, comment: "")
        }
    }

    public var currentPhaseDuration: TimeInterval {
        switch phase {
        case .work: 25 * 60
        case .shortBreak: 5 * 60
        case .longBreak: 15 * 60
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

import Foundation

public struct TimerEntry: Identifiable, Sendable {
    public let id: UUID
    public var label: String
    public let duration: TimeInterval
    public var remaining: TimeInterval
    public var isRunning: Bool
    public var isPaused: Bool

    public init(id: UUID = UUID(), label: String, duration: TimeInterval) {
        self.id = id
        self.label = label
        self.duration = duration
        self.remaining = duration
        self.isRunning = false
        self.isPaused = false
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return 1 - (remaining / duration)
    }

    public var isFinished: Bool {
        remaining <= 0
    }
}

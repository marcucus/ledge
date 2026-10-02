import Foundation

public struct TimerEntry: Identifiable, Sendable, Codable {
    public let id: UUID
    public var label: String
    public let duration: TimeInterval
    public var remaining: TimeInterval
    public var isRunning: Bool
    public var isPaused: Bool
    /// Date de fin absolue utilisée pour rester juste après une veille ou un retard du run loop.
    var scheduledEndDate: Date?

    public init(id: UUID = UUID(), label: String, duration: TimeInterval) {
        self.id = id
        self.label = label
        self.duration = duration
        remaining = duration
        isRunning = false
        isPaused = false
        scheduledEndDate = nil
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(1 - (remaining / duration), 0), 1)
    }

    public var isFinished: Bool {
        remaining <= 0
    }
}

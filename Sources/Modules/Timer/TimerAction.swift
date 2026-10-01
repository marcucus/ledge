import Foundation

public enum TimerAction {
    case start(id: UUID)
    case pause(id: UUID)
    case stop(id: UUID)
    case reset(id: UUID)
}

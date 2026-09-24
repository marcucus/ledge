public enum NotchState: Equatable {
    case collapsed
    case ambient  // sideways expansion with live context pills
    case peeking
    case hud      // compact bar (volume / brightness)
    case expanded
}

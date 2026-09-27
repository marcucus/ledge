import Foundation
import QuartzCore

enum NotchWindowLayout {
    static let openDuration: TimeInterval = 0.46
    static let closeDuration: TimeInterval = 0.32
    static let peekDuration: TimeInterval = 0.20
    static let ambientDuration: TimeInterval = 0.30
    static let hudMinWidth: CGFloat = 280
    static let hudSideMargin: CGFloat = 170
    static let hudBottomMargin: CGFloat = 34

    static var expansionTiming: CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.16, 0.88, 0.28, 1)
    }
}

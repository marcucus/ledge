import AppKit
import SwiftUI

public struct AmbientContent {
    public enum Kind {
        case music(artwork: NSImage?, isPlaying: Bool, elapsed: TimeInterval, duration: TimeInterval)
        case timer(label: String, progress: Double)
        case dropzone(count: Int)
    }

    public let kind: Kind
    public let accentColor: Color
    public let timestamp: Date

    public init(kind: Kind, accentColor: Color = .white) {
        self.kind = kind
        self.accentColor = accentColor
        self.timestamp = Date()
    }
}

import AppKit
import SwiftUI

public struct AmbientContent {
    public enum Kind {
        case music(artwork: NSImage?, isPlaying: Bool)
        case timer(label: String, progress: Double)
        case dropzone(count: Int)
    }

    public let kind: Kind
    public let accentColor: Color

    public init(kind: Kind, accentColor: Color = .white) {
        self.kind = kind
        self.accentColor = accentColor
    }
}

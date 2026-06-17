import SwiftUI

public struct HUDContent {
    public enum Kind { case volume, brightness }

    public let kind: Kind
    public let value: Double // 0.0 – 1.0
    public let isMuted: Bool

    public init(kind: Kind, value: Double, isMuted: Bool = false) {
        self.kind = kind
        self.value = max(0, min(1, value))
        self.isMuted = isMuted
    }

    public var icon: String {
        if isMuted { return "speaker.slash.fill" }
        switch kind {
        case .volume:
            if value < 0.01 { return "speaker.fill" }
            if value < 0.34 { return "speaker.wave.1.fill" }
            if value < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return value < 0.5 ? "sun.min.fill" : "sun.max.fill"
        }
    }

    public var tint: Color {
        switch kind {
        case .volume: .white
        case .brightness: Color(red: 1.0, green: 0.85, blue: 0.2)
        }
    }
}

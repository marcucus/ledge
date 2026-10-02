import SwiftUI

private struct TransientInteractionHandlerKey: EnvironmentKey {
    static let defaultValue: (Bool) -> Void = { _ in }
}

public extension EnvironmentValues {
    var transientInteractionHandler: (Bool) -> Void {
        get { self[TransientInteractionHandlerKey.self] }
        set { self[TransientInteractionHandlerKey.self] = newValue }
    }
}

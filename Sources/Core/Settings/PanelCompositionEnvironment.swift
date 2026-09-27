import SwiftUI

private struct PanelCompositionEnvironmentKey: EnvironmentKey {
    static let defaultValue = PanelComposition.panoramic
}

public extension EnvironmentValues {
    var panelComposition: PanelComposition {
        get { self[PanelCompositionEnvironmentKey.self] }
        set { self[PanelCompositionEnvironmentKey.self] = newValue }
    }
}

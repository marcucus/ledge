import Foundation

public enum PanelComposition: Int, CaseIterable {
    case focused = 0
    case panoramic = 1
    case immersive = 2
}

/// Destination d'un module dans la navigation d'une composition donnée.
public enum ModulePlacement: Int, CaseIterable {
    case bar = 0
    case grid = 1
    case hidden = 2
}

public enum NotchDetectionMode: Int, CaseIterable {
    case automatic = 0
    case manual = 1
}

public enum FullscreenBehavior: Int, CaseIterable {
    case accessible = 0
    case hidden = 1
    case overlay = 2
}

public enum AnimationSpeed: Int, CaseIterable {
    case fast = 0
    case normal = 1
    case slow = 2

    public var scale: Double {
        switch self {
        case .fast: 0.5
        case .normal: 1.0
        case .slow: 1.8
        }
    }
}

public enum ClickBehavior: Int, CaseIterable {
    case expand = 0
    case peek = 1
}

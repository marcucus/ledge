import Foundation

public enum PanelWidth: Int, CaseIterable {
    case compact  = 0
    case standard = 1
    case large    = 2
}

public enum NotchDetectionMode: Int, CaseIterable {
    case automatic = 0
    case manual    = 1
}

public enum FullscreenBehavior: Int, CaseIterable {
    case accessible = 0
    case hidden     = 1
    case overlay    = 2
}

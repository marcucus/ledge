import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case modules
    case display
    case permissions
    case shortcuts
    case about

    var id: String { rawValue }

    var label: LocalizedStringKey { LocalizedStringKey("settings.section.\(rawValue)") }

    var icon: String {
        switch self {
        case .general:     "gearshape"
        case .appearance:  "paintbrush"
        case .modules:     "square.grid.2x2"
        case .display:     "display"
        case .permissions: "lock.shield"
        case .shortcuts:   "keyboard"
        case .about:       "info.circle"
        }
    }
}

import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case modules
    case appProfiles
    case display
    case permissions
    case shortcuts
    case about

    var id: String {
        rawValue
    }

    var label: LocalizedStringKey {
        switch self {
        case .general: "settings.section.general"
        case .appearance: "settings.section.appearance"
        case .modules: "settings.section.modules"
        case .appProfiles: "settings.section.appProfiles"
        case .display: "settings.section.display"
        case .permissions: "settings.section.permissions"
        case .shortcuts: "settings.section.shortcuts"
        case .about: "settings.section.about"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .modules: "square.grid.2x2"
        case .appProfiles: "app.badge"
        case .display: "display"
        case .permissions: "lock.shield"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }
}

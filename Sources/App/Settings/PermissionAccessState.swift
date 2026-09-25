import SwiftUI

enum PermissionAccessState {
    case granted
    case notRequested
    case denied
    case onDemand
    case unavailable

    var icon: String {
        switch self {
        case .granted: "checkmark.circle.fill"
        case .notRequested: "circle.dashed"
        case .denied: "exclamationmark.triangle.fill"
        case .onDemand: "clock.badge.checkmark"
        case .unavailable: "minus.circle"
        }
    }

    var color: Color {
        switch self {
        case .granted: .green
        case .notRequested, .onDemand, .unavailable: .secondary
        case .denied: .orange
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .granted: "settings.permissions.status.granted"
        case .notRequested: "settings.permissions.status.notRequested"
        case .denied: "settings.permissions.status.denied"
        case .onDemand: "settings.permissions.status.onDemand"
        case .unavailable: "settings.permissions.status.unavailable"
        }
    }
}

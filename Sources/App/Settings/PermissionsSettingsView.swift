import SwiftUI
import AppKit
import Core
import UserNotifications
import ApplicationServices

struct PermissionsSettingsView: View {
    @State private var accessibilityGranted = false
    @State private var notificationsStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        Form {
            Section {
                permissionRow(
                    icon: "figure.arms.open",
                    nameKey: "settings.permissions.accessibility",
                    statusIcon: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    statusColor: accessibilityGranted ? Color.green : Color.orange,
                    showAction: !accessibilityGranted,
                    action: accessibilityGranted ? nil : openAccessibilitySettings
                )

                permissionRow(
                    icon: "bell.badge",
                    nameKey: "settings.permissions.notifications",
                    statusIcon: notificationStatusIcon,
                    statusColor: notificationStatusColor,
                    showAction: notificationsStatus == .denied,
                    action: notificationsStatus == .denied ? openNotificationSettings : nil
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.permissions", bundle: localizationBundle))
        .task { await refreshStatus() }
    }

    private var notificationStatusIcon: String {
        switch notificationsStatus {
        case .authorized, .provisional, .ephemeral: "checkmark.circle.fill"
        case .denied:                                "xmark.circle.fill"
        default:                                     "questionmark.circle.fill"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationsStatus {
        case .authorized, .provisional, .ephemeral: .green
        case .denied:                                .red
        default:                                     .secondary
        }
    }

    private func permissionRow(
        icon: String,
        nameKey: String,
        statusIcon: String,
        statusColor: Color,
        showAction: Bool,
        action: (() -> Void)?
    ) -> some View {
        HStack {
            Label {
                Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
            } icon: {
                Image(systemName: icon)
            }
            Spacer()
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            if showAction, let action {
                Button(action: action) {
                    Text("settings.permissions.openSettings", bundle: localizationBundle)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func refreshStatus() async {
        accessibilityGranted = AXIsProcessTrusted()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsStatus = settings.authorizationStatus
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
}

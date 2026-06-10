import SwiftUI
import AppKit
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
                    actionLabel: accessibilityGranted ? nil : LocalizedStringKey("settings.permissions.openSettings"),
                    action: accessibilityGranted ? nil : openAccessibilitySettings
                )

                permissionRow(
                    icon: "bell.badge",
                    nameKey: "settings.permissions.notifications",
                    statusIcon: notificationStatusIcon,
                    statusColor: notificationStatusColor,
                    actionLabel: notificationsStatus == .denied ? LocalizedStringKey("settings.permissions.openSettings") : nil,
                    action: notificationsStatus == .denied ? openNotificationSettings : nil
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.permissions"))
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
        nameKey: LocalizedStringKey,
        statusIcon: String,
        statusColor: Color,
        actionLabel: LocalizedStringKey?,
        action: (() -> Void)?
    ) -> some View {
        HStack {
            Label(nameKey, systemImage: icon)
            Spacer()
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
            if let actionLabel, let action {
                Button(action: action) {
                    Text(actionLabel)
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

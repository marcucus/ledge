import AppKit
import ApplicationServices
import Core
import SwiftUI
import UserNotifications

struct PermissionsSettingsView: View {
    @State private var accessibilityGranted = false
    @State private var notificationsGranted = false
    /// En run non-bundlé (swift run), UNUserNotificationCenter n'est pas disponible.
    private let notificationsAvailable = Bundle.main.bundleIdentifier != nil

    var body: some View {
        Form {
            Section {
                permissionRow(
                    icon: "figure.arms.open",
                    nameKey: "settings.permissions.accessibility",
                    granted: accessibilityGranted,
                    actionKey: "settings.permissions.openSettings",
                    action: openAccessibilitySettings
                )
                if notificationsAvailable {
                    permissionRow(
                        icon: "bell.badge",
                        nameKey: "settings.permissions.notifications",
                        granted: notificationsGranted,
                        actionKey: "settings.permissions.request",
                        action: requestNotifications
                    )
                }
                automationRow
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.permissions", bundle: localizationBundle))
        .task {
            accessibilityGranted = AXIsProcessTrusted()
            await refreshNotifications()
        }
    }

    private func permissionRow(
        icon: String,
        nameKey: String,
        granted: Bool,
        actionKey: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Label {
                Text(LocalizedStringKey(nameKey), bundle: localizationBundle)
            } icon: {
                Image(systemName: icon)
            }
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? Color.green : Color.orange)
            if !granted {
                Button(action: action) {
                    Text(LocalizedStringKey(actionKey), bundle: localizationBundle)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// L'Automation (Apple Music) suit la demande paresseuse : accordée au 1er contrôle (doc 07).
    private var automationRow: some View {
        HStack {
            Label {
                Text("settings.permissions.automation", bundle: localizationBundle)
            } icon: {
                Image(systemName: "applescript")
            }
            Spacer()
            Text("settings.permissions.automation.detail", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestNotifications() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshNotifications()
        }
    }

    private func refreshNotifications() async {
        guard notificationsAvailable else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsGranted = settings.authorizationStatus == .authorized
    }
}

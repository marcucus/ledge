import SwiftUI
import AppKit
import Core
import ApplicationServices

struct PermissionsSettingsView: View {
    @State private var accessibilityGranted = false

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
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.permissions", bundle: localizationBundle))
        .task { accessibilityGranted = AXIsProcessTrusted() }
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

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

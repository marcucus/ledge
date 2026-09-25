import AppKit
import ApplicationServices
import Core
import EventKit
import SwiftUI
import UserNotifications

struct PermissionsSettingsView: View {
    @State private var accessibilityGranted = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var calendarStatus: EKAuthorizationStatus = .notDetermined

    private let notificationsAvailable = Bundle.main.bundleIdentifier != nil
    private let calendarStore = EKEventStore()

    var body: some View {
        Form {
            Section {
                Text("settings.permissions.intro", bundle: localizationBundle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                PermissionRow(
                    icon: "figure.arms.open",
                    nameKey: "settings.permissions.accessibility",
                    detailKey: "settings.permissions.accessibility.detail",
                    state: accessibilityGranted ? .granted : .notRequested,
                    actionKey: accessibilityGranted ? nil : "settings.permissions.openSettings",
                    action: accessibilityGranted ? nil : openAccessibilitySettings
                )
                PermissionRow(
                    icon: "bell.badge",
                    nameKey: "settings.permissions.notifications",
                    detailKey: "settings.permissions.notifications.detail",
                    state: notificationAccessState,
                    actionKey: notificationActionKey,
                    action: notificationAction
                )
                PermissionRow(
                    icon: "calendar",
                    nameKey: "settings.permissions.calendar",
                    detailKey: "settings.permissions.calendar.detail",
                    state: calendarAccessState,
                    actionKey: calendarActionKey,
                    action: calendarAction
                )
                PermissionRow(
                    icon: "applescript",
                    nameKey: "settings.permissions.automation",
                    detailKey: "settings.permissions.automation.detail",
                    state: .onDemand,
                    actionKey: nil,
                    action: nil
                )
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.permissions", bundle: localizationBundle))
        .task { await refreshStatuses() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshStatuses() }
        }
    }

    private var notificationAccessState: PermissionAccessState {
        guard notificationsAvailable else { return .unavailable }
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notRequested
        @unknown default: return .notRequested
        }
    }

    private var notificationActionKey: LocalizedStringKey? {
        switch notificationAccessState {
        case .notRequested: return "settings.permissions.request"
        case .denied: return "settings.permissions.openSettings"
        case .granted, .onDemand, .unavailable: return nil
        }
    }

    private var notificationAction: (() -> Void)? {
        switch notificationAccessState {
        case .notRequested: return requestNotifications
        case .denied: return openNotificationSettings
        case .granted, .onDemand, .unavailable: return nil
        }
    }

    private var calendarAccessState: PermissionAccessState {
        switch calendarStatus {
        case .fullAccess: return .granted
        case .notDetermined: return .notRequested
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default: return .notRequested
        }
    }

    private var calendarActionKey: LocalizedStringKey? {
        switch calendarAccessState {
        case .notRequested: return "settings.permissions.request"
        case .denied: return "settings.permissions.openSettings"
        case .granted, .onDemand, .unavailable: return nil
        }
    }

    private var calendarAction: (() -> Void)? {
        switch calendarAccessState {
        case .notRequested: return requestCalendar
        case .denied: return openCalendarSettings
        case .granted, .onDemand, .unavailable: return nil
        }
    }

    private func openAccessibilitySettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func openNotificationSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.notifications")
    }

    private func openCalendarSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
    }

    private func openSystemSettings(_ path: String) {
        guard let url = URL(string: path) else { return }
        NSWorkspace.shared.open(url)
    }

    private func requestNotifications() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            await refreshStatuses()
        }
    }

    private func requestCalendar() {
        Task {
            _ = try? await calendarStore.requestFullAccessToEvents()
            await refreshStatuses()
        }
    }

    @MainActor
    private func refreshStatuses() async {
        accessibilityGranted = AXIsProcessTrusted()
        calendarStatus = EKEventStore.authorizationStatus(for: .event)
        guard notificationsAvailable else { return }
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

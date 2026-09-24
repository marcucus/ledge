import AppKit
import Core
import EventKit
import SwiftUI

// MARK: — CalendarContentView

/// Full content view: next event title + relative time, a "permission required" state
/// with a button opening System Settings → Privacy, or an "no upcoming events" message.
public struct CalendarContentView: View {
    public var module: CalendarModule

    public init(module: CalendarModule) {
        self.module = module
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if module.authorizationDenied {
                permissionRequiredView
            } else if let event = module.nextEvent {
                eventView(event)
            } else {
                emptyView
            }
        }
        .padding(12)
        .onAppear { module.beginPolling() }
        .onDisappear { module.endPolling() }
    }

    // MARK: — Event

    private func eventView(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title ?? "")
                .font(.callout.weight(.semibold))
                .lineLimit(2)
            Text(relativeTime(for: event.startDate))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func relativeTime(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: — Empty state

    private var emptyView: some View {
        Text("calendar.empty", bundle: localizationBundle)
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 4)
    }

    // MARK: — Permission required

    private var permissionRequiredView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("calendar.permission.required", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button(action: openCalendarPrivacySettings) {
                Text("settings.permissions.openSettings", bundle: localizationBundle)
                    .font(.footnote.weight(.medium))
            }
            .buttonStyle(.bordered)
        }
    }

    private func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")
        else { return }
        NSWorkspace.shared.open(url)
    }
}

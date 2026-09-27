import Core
import EventKit
import Foundation
import SwiftUI

public enum CalendarAccessState {
    case notDetermined
    case authorized
    case denied
}

// MARK: — CalendarModule

/// Surfaces the next upcoming calendar event (EventKit), refreshed periodically
/// while the module is visible. Degrades cleanly when Calendar access is denied
/// or not yet determined — never reads events without authorization.
@MainActor
@Observable
public final class CalendarModule: NotchModule {
    public let id = "calendar"
    public let tabIcon = "calendar"
    public let tabLabel: LocalizedStringKey = "module.calendar.label"

    public private(set) var nextEvent: EKEvent?
    public private(set) var accessState: CalendarAccessState = .notDetermined

    @ObservationIgnored private let eventStore = EKEventStore()
    @ObservationIgnored private nonisolated(unsafe) var refreshTimer: Timer?
    @ObservationIgnored private let lookahead: TimeInterval = 24 * 60 * 60

    public init() {}

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: — NotchModule

    public func start() {
        refreshAccessState()
        if accessState == .authorized {
            refreshNextEvent()
        }
    }

    public func stop() {
        endPolling()
    }

    public func makePeekView() -> AnyView {
        AnyView(CalendarPeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(CalendarContentView(module: self))
    }

    // MARK: — Polling lifecycle (called by the content view)

    /// Call from the content view's `onAppear`.
    func beginPolling() {
        refreshAccessState()
        switch accessState {
        case .authorized:
            refreshNextEvent()
            startPollingIfNeeded()
        case .notDetermined:
            Task { await requestAccessAndRefresh() }
        case .denied:
            nextEvent = nil
        }
    }

    private func startPollingIfNeeded() {
        guard refreshTimer == nil, accessState == .authorized else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshNextEvent() }
        }
        refreshTimer = timer
    }

    /// Call from the content view's `onDisappear`.
    func endPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: — Authorization

    func requestAccessAndRefresh() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            accessState = granted ? .authorized : .denied
            if granted {
                refreshNextEvent()
                startPollingIfNeeded()
            } else {
                nextEvent = nil
            }
        } catch {
            accessState = .denied
            nextEvent = nil
        }
    }

    private func refreshAccessState() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            accessState = .authorized
        case .notDetermined:
            accessState = .notDetermined
        default:
            accessState = .denied
        }
    }

    // MARK: — Event lookup

    private func refreshNextEvent() {
        guard accessState == .authorized else { return }
        let now = Date()
        let end = now.addingTimeInterval(lookahead)
        let predicate = eventStore.predicateForEvents(withStart: now, end: end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        nextEvent = events
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
}

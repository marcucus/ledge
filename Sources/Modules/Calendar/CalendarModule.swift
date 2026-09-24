import Core
import EventKit
import Foundation
import SwiftUI

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
    public private(set) var authorizationDenied: Bool = false

    @ObservationIgnored private let eventStore = EKEventStore()
    @ObservationIgnored private nonisolated(unsafe) var refreshTimer: Timer?
    @ObservationIgnored private let lookahead: TimeInterval = 24 * 60 * 60

    public init() {}

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: — NotchModule

    public func start() {
        Task { await requestAccessAndRefresh() }
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
        guard refreshTimer == nil else { return }
        // Re-tente l'accès à chaque affichage : si l'utilisateur l'a accordé après coup (via
        // Réglages Système), la vue de permission se débloque sans relancer l'app.
        Task { await requestAccessAndRefresh() }
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

    private func requestAccessAndRefresh() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationDenied = !granted
            if granted {
                refreshNextEvent()
            }
        } catch {
            authorizationDenied = true
        }
    }

    // MARK: — Event lookup

    private func refreshNextEvent() {
        guard !authorizationDenied else { return }
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

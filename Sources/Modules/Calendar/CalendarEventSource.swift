import EventKit
import Foundation

@MainActor
protocol CalendarEventSource: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    func requestFullAccess() async throws -> Bool
    func events(from start: Date, to end: Date) -> [EKEvent]
}

@MainActor
final class EventKitCalendarEventSource: CalendarEventSource {
    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestFullAccess() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func events(from start: Date, to end: Date) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }
}

@testable import CalendarModule
import EventKit
import Foundation
import Testing

@MainActor
private final class StubCalendarEventSource: CalendarEventSource {
    var authorizationStatus: EKAuthorizationStatus
    var accessResult: Result<Bool, Error> = .success(false)
    var upcomingEvents: [EKEvent] = []
    private(set) var requestCount = 0
    private(set) var eventQueryCount = 0

    init(authorizationStatus: EKAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
    }

    func requestFullAccess() async throws -> Bool {
        requestCount += 1
        return try accessResult.get()
    }

    func events(from _: Date, to _: Date) -> [EKEvent] {
        eventQueryCount += 1
        return upcomingEvents
    }
}

@MainActor
struct CalendarModuleTests {
    @Test func startLoadsNextEventWhenAccessIsAuthorized() {
        let source = StubCalendarEventSource(authorizationStatus: .fullAccess)
        let eventStore = EKEventStore()
        let later = EKEvent(eventStore: eventStore)
        later.title = "Later"
        later.startDate = Date().addingTimeInterval(3_600)
        later.endDate = Date().addingTimeInterval(4_200)
        let sooner = EKEvent(eventStore: eventStore)
        sooner.title = "Sooner"
        sooner.startDate = Date().addingTimeInterval(600)
        sooner.endDate = Date().addingTimeInterval(1_200)
        source.upcomingEvents = [later, sooner]
        let module = CalendarModule(eventSource: source)

        module.start()

        #expect(module.accessState == .authorized)
        #expect(module.nextEvent?.title == "Sooner")
        #expect(source.eventQueryCount == 1)
    }

    @Test func deniedAccessNeverReadsEventsOrStartsPolling() {
        let source = StubCalendarEventSource(authorizationStatus: .denied)
        let module = CalendarModule(eventSource: source)

        module.start()
        module.beginPolling()

        #expect(module.accessState == .denied)
        #expect(module.nextEvent == nil)
        #expect(source.eventQueryCount == 0)
        #expect(!module.isPolling)
    }

    @Test func grantedRequestRefreshesAndStartsPolling() async {
        let source = StubCalendarEventSource(authorizationStatus: .notDetermined)
        source.accessResult = .success(true)
        let module = CalendarModule(eventSource: source)

        await module.requestAccessAndRefresh()

        #expect(module.accessState == .authorized)
        #expect(source.requestCount == 1)
        #expect(source.eventQueryCount == 1)
        #expect(module.isPolling)
        module.stop()
        #expect(!module.isPolling)
    }

    @Test func refusedRequestDoesNotPoll() async {
        let source = StubCalendarEventSource(authorizationStatus: .notDetermined)
        source.accessResult = .success(false)
        let module = CalendarModule(eventSource: source)

        await module.requestAccessAndRefresh()

        #expect(module.accessState == .denied)
        #expect(source.eventQueryCount == 0)
        #expect(!module.isPolling)
    }

    @Test func requestErrorIsDistinctFromUserRefusal() async {
        struct RequestError: Error {}
        let source = StubCalendarEventSource(authorizationStatus: .notDetermined)
        source.accessResult = .failure(RequestError())
        let module = CalendarModule(eventSource: source)

        await module.requestAccessAndRefresh()

        #expect(module.accessState == .requestFailed)
        #expect(source.eventQueryCount == 0)
        #expect(!module.isPolling)
    }
}

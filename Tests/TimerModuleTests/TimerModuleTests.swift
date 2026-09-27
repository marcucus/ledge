@testable import TimerModule
import Foundation
import Testing

@MainActor
struct TimerModuleTests {
    @Test func timerUsesAbsoluteDeadlineAfterLongPause() {
        let module = TimerModule()
        guard let id = module.addAndStart(label: "Test", duration: 120),
              let endDate = module.entries.first?.scheduledEndDate
        else {
            Issue.record("Timer should start with an absolute deadline")
            return
        }

        module.synchronizeTimer(id: id, now: endDate.addingTimeInterval(-30))

        #expect(module.entries.first?.remaining == 30)
    }

    @Test func elapsedTimerFinishesImmediatelyAfterWake() {
        let module = TimerModule()
        guard let id = module.addAndStart(label: "Test", duration: 60),
              let endDate = module.entries.first?.scheduledEndDate
        else {
            Issue.record("Timer should start with an absolute deadline")
            return
        }

        module.synchronizeTimer(id: id, now: endDate.addingTimeInterval(10))

        #expect(module.entries.first?.remaining == 0)
        #expect(module.entries.first?.isRunning == false)
    }

    @Test func progressAlwaysStaysInUnitRange() {
        var beforeStart = TimerEntry(label: "Before", duration: 10)
        beforeStart.remaining = 20
        var afterEnd = TimerEntry(label: "After", duration: 10)
        afterEnd.remaining = -5

        #expect(beforeStart.progress == 0)
        #expect(afterEnd.progress == 1)
    }
}

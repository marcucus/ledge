@testable import ClipboardModule
import Foundation
import Testing

@MainActor
struct ClipboardModuleTests {
    @Test func pinnedItemsStayFirstAndEachGroupIsNewestFirst() {
        let old = Date(timeIntervalSince1970: 100)
        let recent = Date(timeIntervalSince1970: 200)
        let items = [
            ClipboardItem(content: .text("recent"), date: recent),
            ClipboardItem(content: .text("old pinned"), date: old, isPinned: true),
            ClipboardItem(content: .text("old"), date: old),
            ClipboardItem(content: .text("recent pinned"), date: recent, isPinned: true),
        ]

        let ordered = ClipboardModule.orderedForDisplay(items)

        #expect(ordered.map(\.content.previewText) == ["recent pinned", "old pinned", "recent", "old"])
    }
}

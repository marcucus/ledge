@testable import DropZoneModule
import Foundation
import Testing

struct DropZoneModuleTests {
    @Test func shelfItemBecomesUnavailableWhenSourceDisappears() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-dropzone-\(UUID().uuidString).txt")
        let data = Data("test".utf8)
        try data.write(to: url)
        let item = ShelfItem(url: url)
        #expect(item.isAvailable)

        try FileManager.default.removeItem(at: url)

        #expect(!item.isAvailable)
    }
}

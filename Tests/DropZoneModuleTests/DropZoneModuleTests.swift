@testable import DropZoneModule
import Core
import Foundation
import Testing

struct DropZoneModuleTests {
    @Test @MainActor func stopClearsDragStateAndAmbientContribution() {
        let module = DropZoneModule()
        var updates: [AmbientContent?] = []
        module.onAmbientUpdate = { updates.append($0) }
        module.start()
        module.isDragActive = true
        #expect(updates.last.flatMap { $0 } != nil)

        module.stop()

        #expect(!module.isDragActive)
        #expect(updates.last.flatMap { $0 } == nil)
    }

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

    // MARK: — Collisions de copie (doc 13, Jalon 3)

    @Test @MainActor func uniqueDestinationReturnsOriginalNameWhenFree() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let module = DropZoneModule()
        let dest = module.uniqueDestination(for: "photo.png", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("photo.png"))
    }

    @Test @MainActor func uniqueDestinationAddsFinderStyleSuffixOnCollision() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo.png"))

        let module = DropZoneModule()
        let dest = module.uniqueDestination(for: "photo.png", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("photo 2.png"))
    }

    @Test @MainActor func uniqueDestinationSkipsEveryTakenSuffix() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo.png"))
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo 2.png"))
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo 3.png"))

        let module = DropZoneModule()
        let dest = module.uniqueDestination(for: "photo.png", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("photo 4.png"))
    }

    @Test @MainActor func uniqueDestinationHandlesNamesWithoutExtension() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("existing".utf8).write(to: dir.appendingPathComponent("README"))

        let module = DropZoneModule()
        let dest = module.uniqueDestination(for: "README", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("README 2"))
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-dropzone-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

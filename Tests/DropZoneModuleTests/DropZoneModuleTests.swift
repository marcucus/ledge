@testable import DropZoneModule
import Core
import Foundation
import Testing

struct DropZoneModuleTests {
    @Test @MainActor func injectedSettingsControlFolderAcceptance() throws {
        let suiteName = "ledge.dropzone.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Unable to create isolated UserDefaults suite")
            return
        }
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.dropZoneAcceptFolders = false
        let module = DropZoneModule(settings: settings)
        let directory = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        module.addURLs([directory])

        #expect(module.items.isEmpty)
    }

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

        let copier = DropZoneFileCopier()
        let dest = copier.uniqueDestination(for: "photo.png", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("photo.png"))
    }

    @Test @MainActor func uniqueDestinationAddsFinderStyleSuffixOnCollision() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo.png"))

        let copier = DropZoneFileCopier()
        let dest = copier.uniqueDestination(for: "photo.png", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("photo 2.png"))
    }

    @Test @MainActor func uniqueDestinationSkipsEveryTakenSuffix() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo.png"))
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo 2.png"))
        try Data("existing".utf8).write(to: dir.appendingPathComponent("photo 3.png"))

        let copier = DropZoneFileCopier()
        let dest = copier.uniqueDestination(for: "photo.png", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("photo 4.png"))
    }

    @Test @MainActor func uniqueDestinationHandlesNamesWithoutExtension() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("existing".utf8).write(to: dir.appendingPathComponent("README"))

        let copier = DropZoneFileCopier()
        let dest = copier.uniqueDestination(for: "README", in: dir, fileManager: .default)

        #expect(dest == dir.appendingPathComponent("README 2"))
    }

    @Test @MainActor func copyRunsThroughInjectedCopierAndPublishesProgress() async throws {
        let sourceDirectory = try makeTempDirectory()
        let destinationDirectory = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }
        let first = sourceDirectory.appendingPathComponent("one.txt")
        let second = sourceDirectory.appendingPathComponent("two.txt")
        try Data("one".utf8).write(to: first)
        try Data("two".utf8).write(to: second)
        let recorder = RecordingDropZoneCopier()
        let module = DropZoneModule(fileCopier: recorder)
        module.addURLs([first, second])

        await module.copyItems(to: destinationDirectory)

        #expect(await recorder.copyCount == 2)
        #expect(module.copiedItemCount == 2)
        #expect(module.copyItemCount == 2)
        #expect(module.copyProgress == 1)
        #expect(module.lastCopyFailureCount == 0)
        #expect(!module.isCopying)
    }

    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-dropzone-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

private actor RecordingDropZoneCopier: DropZoneCopying {
    private(set) var copyCount = 0

    func copy(_ request: DropZoneCopyRequest, to directory: URL) async -> Bool {
        copyCount += 1
        return true
    }
}

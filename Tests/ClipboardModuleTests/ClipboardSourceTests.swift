import AppKit
@testable import ClipboardModule
import Testing

/// Ces tests ne touchent jamais `NSPasteboard.general` : `NSPasteboardItem` est un simple
/// conteneur de données, indépendant du presse-papiers système tant qu'il n'y est pas posé.
struct ClipboardSourceTests {
    private func makePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("ledge.clipboard.tests.\(UUID().uuidString)"))
    }

    private func makeItem(sourceBundleIdentifier: String?) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        if let sourceBundleIdentifier {
            item.setData(
                Data(sourceBundleIdentifier.utf8),
                forType: NSPasteboard.PasteboardType("org.nspasteboard.source")
            )
        }
        item.setString("some text", forType: .string)
        return item
    }

    @Test @MainActor func sourceBundleIdentifierReadsVoluntaryDeclaration() {
        let source = ClipboardSource()
        let item = makeItem(sourceBundleIdentifier: "com.1password.1password")

        #expect(source.sourceBundleIdentifier(for: [item]) == "com.1password.1password")
    }

    @Test @MainActor func isExcludedSourceMatchesConfiguredBundleIdentifier() {
        let source = ClipboardSource()
        source.excludedBundleIdentifiers = ["com.1password.1password"]
        let item = makeItem(sourceBundleIdentifier: "com.1password.1password")

        #expect(source.isExcludedSource(for: [item]))
    }

    @Test @MainActor func isExcludedSourceIsFalseWhenBundleIdentifierNotExcluded() {
        let source = ClipboardSource()
        source.excludedBundleIdentifiers = ["com.1password.1password"]
        let item = makeItem(sourceBundleIdentifier: "com.apple.TextEdit")

        #expect(!source.isExcludedSource(for: [item]))
    }

    @Test @MainActor func isExcludedSourceIsFalseWhenNoExclusionConfigured() {
        let source = ClipboardSource()
        let item = makeItem(sourceBundleIdentifier: "com.apple.TextEdit")

        #expect(!source.isExcludedSource(for: [item]))
    }

    @Test @MainActor func capturedImageKeepsItsOriginalDimensions() throws {
        let source = ClipboardSource()
        let original = NSImage(size: NSSize(width: 640, height: 360))
        original.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(origin: .zero, size: original.size).fill()
        original.unlockFocus()
        let data = try #require(original.tiffRepresentation)
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setData(data, forType: .tiff)
        let captured = source.buildItem(from: [pasteboardItem])

        guard case let .image(image) = captured?.content else {
            Issue.record("Expected a captured image")
            return
        }
        #expect(image.size == original.size)
    }

    @Test @MainActor func synchronizedChangeIsNotCapturedAgain() {
        let pasteboard = makePasteboard()
        pasteboard.clearContents()
        let source = ClipboardSource(pasteboard: pasteboard)
        var captureCount = 0
        source.onNewItem = { _ in captureCount += 1 }

        pasteboard.setString("written by Ledge", forType: .string)
        source.synchronizeChangeCount()
        source.poll()

        #expect(captureCount == 0)
    }
}

import AppKit
@testable import ClipboardModule
import Testing

/// Ces tests ne touchent jamais `NSPasteboard.general` : `NSPasteboardItem` est un simple
/// conteneur de données, indépendant du presse-papiers système tant qu'il n'y est pas posé.
struct ClipboardSourceTests {
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
}

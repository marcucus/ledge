import AppKit
import Foundation

// MARK: — ClipboardSource

//
// Why polling?  NSPasteboard offers no push-notification API for copy events.
// We watch `changeCount` (a lightweight integer comparison) every 0.8 s.
// This is the ONLY exception to the project's "zero polling" rule, and its
// CPU impact is negligible — a single integer read per tick.

/// Watches `NSPasteboard` for new copies and publishes `ClipboardItem` values.
final class ClipboardSource {
    /// Called on the main actor whenever a new item is detected.
    var onNewItem: ((ClipboardItem) -> Void)?

    /// Configurable max-history size (set by the module before starting)
    var maxItems: Int = 50

    /// Identifiants de bundle dont les copies ne doivent jamais être capturées (doc 13,
    /// Jalon 3, item 18), tenu à jour par `ClipboardModule` depuis `SettingsStore`.
    var excludedBundleIdentifiers: Set<String> = []

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let pasteboard = NSPasteboard.general

    /// Concealed-type UTI used by password managers to flag sensitive copies.
    private static let concealedType = "org.nspasteboard.ConcealedType"

    /// UTI (convention non officielle nspasteboard.org) par laquelle une app bien élevée
    /// déclare volontairement son identifiant de bundle comme source de la copie.
    private static let sourceType = "org.nspasteboard.source"

    /// Thumbnail max dimension in points.
    private static let thumbnailMaxSide: CGFloat = 128

    // MARK: — Lifecycle

    func start() {
        lastChangeCount = pasteboard.changeCount
        timer = Timer.scheduledTimer(
            withTimeInterval: 0.8,
            repeats: true
        ) { [weak self] _ in self?.poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: — Poll

    private func poll() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard let item = buildItem() else { return }
        onNewItem?(item)
    }

    // MARK: — Build item

    private func buildItem() -> ClipboardItem? {
        guard let items = pasteboard.pasteboardItems, !items.isEmpty else { return nil }

        // Security: skip copies from password managers
        for item in items where item.types.contains(
            NSPasteboard.PasteboardType(ClipboardSource.concealedType)
        ) {
            return nil
        }

        guard !isExcludedSource(for: items) else { return nil }

        guard let first = items.first else { return nil }

        // Prefer URL > image > text
        // NSPasteboardType.URL is "public.url" — check it first, fall back to string parse
        let urlTypes: [NSPasteboard.PasteboardType] = [.URL, NSPasteboard.PasteboardType("public.file-url")]
        let urlString = urlTypes.lazy.compactMap { first.string(forType: $0) }.first
        if let urlStr = urlString, let url = URL(string: urlStr), url.scheme != nil {
            return ClipboardItem(content: .url(url))
        }

        if let tiffData = first.data(forType: .tiff) ?? first.data(forType: .png),
           let image = NSImage(data: tiffData)
        {
            let thumbnail = makeThumbnail(from: image)
            return ClipboardItem(content: .image(thumbnail))
        }

        if let string = first.string(forType: .string), !string.isEmpty {
            return ClipboardItem(content: .text(string))
        }

        return nil
    }

    // MARK: — Source app

    /// Accès `internal` (plutôt que `private`) pour rester testable via `@testable import`
    /// sans jamais toucher `NSPasteboard.general` dans les tests (doc 13, Jalon 3, item 18).
    /// Vrai si la copie doit être ignorée car sa source figure dans `excludedBundleIdentifiers`.
    func isExcludedSource(for items: [NSPasteboardItem]) -> Bool {
        guard let bundleID = sourceBundleIdentifier(for: items) else { return false }
        return excludedBundleIdentifiers.contains(bundleID)
    }

    /// Préfère la déclaration volontaire de l'app copiante (`org.nspasteboard.source`, non
    /// implémentée par la majorité des apps) et, à défaut, retombe sur l'app au premier plan au
    /// moment du sondage — une approximation raisonnable : aucune API publique n'expose la
    /// source réelle d'une copie sur `NSPasteboard`.
    func sourceBundleIdentifier(for items: [NSPasteboardItem]) -> String? {
        for item in items {
            if let data = item.data(forType: NSPasteboard.PasteboardType(ClipboardSource.sourceType)),
               let bundleID = String(data: data, encoding: .utf8), !bundleID.isEmpty
            {
                return bundleID
            }
        }
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    // MARK: — Thumbnail

    private func makeThumbnail(from image: NSImage) -> NSImage {
        let side = ClipboardSource.thumbnailMaxSide
        let size = image.size
        guard size.width > side || size.height > side else { return image }

        let ratio = min(side / size.width, side / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: newSize))
        thumb.unlockFocus()
        return thumb
    }
}

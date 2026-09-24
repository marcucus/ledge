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

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let pasteboard = NSPasteboard.general

    /// Concealed-type UTI used by password managers to flag sensitive copies.
    private static let concealedType = "org.nspasteboard.ConcealedType"

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

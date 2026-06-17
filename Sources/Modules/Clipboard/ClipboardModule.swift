import AppKit
import Core
import Foundation
import SwiftUI

// MARK: — ClipboardModule

@MainActor
@Observable
public final class ClipboardModule: NotchModule {
    public let id = "clipboard"

    /// Ordered from newest to oldest; capped at `maxItems`.
    private(set) var items: [ClipboardItem] = []

    @ObservationIgnored private let maxItems = 50
    @ObservationIgnored private let source = ClipboardSource()

    /// nonisolated(unsafe) so deinit (non-isolated) can reach it
    @ObservationIgnored private nonisolated(unsafe) var _source: ClipboardSource

    public init() {
        _source = source
        source.maxItems = maxItems
        source.onNewItem = { [weak self] item in
            guard let self else { return }
            Task { @MainActor in self.append(item) }
        }
    }

    deinit {
        _source.stop()
    }

    // MARK: — NotchModule

    public func start() {
        source.start()
    }

    public func stop() {
        source.stop()
    }

    // MARK: — Public API

    /// Re-places `item` into the pasteboard and simulates Cmd+V in the frontmost app.
    func paste(item: ClipboardItem) {
        writeToPasteboard(item)
        simulatePaste()
    }

    /// Clears the history.
    func clearHistory() {
        items.removeAll()
    }

    // MARK: — Private helpers

    private func append(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
    }

    private func writeToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.content {
        case let .text(text):
            pasteboard.setString(text, forType: .string)
        case let .url(url):
            pasteboard.setString(url.absoluteString, forType: .string)
            pasteboard.setString(url.absoluteString, forType: .URL)
        case let .image(img):
            if let tiff = img.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
    }

    private func simulatePaste() {
        // Post Cmd+V key-down / key-up via CGEvent to trigger paste in the active app.
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

// MARK: — NotchModule protocol conformance

public extension ClipboardModule {
    var tabIcon: String {
        "doc.on.clipboard"
    }

    var tabLabel: LocalizedStringKey {
        "module.clipboard.label"
    }

    func makePeekView() -> AnyView {
        AnyView(ClipboardPeekView(module: self))
    }

    func makeContentView() -> AnyView {
        AnyView(ClipboardContentView(module: self))
    }
}

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

    // nonisolated(unsafe) so deinit (non-isolated) can reach it
    @ObservationIgnored nonisolated(unsafe) private var _source: ClipboardSource

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
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.content {
        case .text(let s):
            pb.setString(s, forType: .string)
        case .url(let u):
            pb.setString(u.absoluteString, forType: .string)
            pb.setString(u.absoluteString, forType: .URL)
        case .image(let img):
            if let tiff = img.tiffRepresentation {
                pb.setData(tiff, forType: .tiff)
            }
        }
    }

    private func simulatePaste() {
        // Post Cmd+V key-down / key-up via CGEvent to trigger paste in the active app.
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags   = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

// MARK: — NotchModule protocol conformance

extension ClipboardModule {
    public var tabIcon: String { "doc.on.clipboard" }
    public var tabLabel: LocalizedStringKey { "module.clipboard.label" }
    public func makePeekView() -> AnyView { AnyView(ClipboardPeekView(module: self)) }
    public func makeContentView() -> AnyView { AnyView(ClipboardContentView(module: self)) }
}

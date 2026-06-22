import AppKit
import Core
import Foundation
import SwiftUI

// MARK: — ClipboardModule

@MainActor
@Observable
public final class ClipboardModule: NotchModule {
    public let id = "clipboard"

    /// Ordered from newest to oldest; capped at `clipboardMaxItems` from SettingsStore (0 = unlimited).
    private(set) var items: [ClipboardItem] = []

    @ObservationIgnored private let source = ClipboardSource()

    /// nonisolated(unsafe) so deinit (non-isolated) can reach it
    @ObservationIgnored private nonisolated(unsafe) var _source: ClipboardSource

    public init() {
        _source = source
    }

    deinit {
        _source.stop()
    }

    // MARK: — NotchModule

    public func start() {
        let max = SettingsStore.shared.clipboardMaxItems
        source.maxItems = max > 0 ? max : Int.max
        source.onNewItem = { [weak self] item in
            guard let self else { return }
            Task { @MainActor in self.append(item) }
        }
        source.start()
        observeMaxItems()
    }

    public func stop() {
        source.stop()
    }

    // MARK: — Public API

    func paste(item: ClipboardItem) {
        writeToPasteboard(item)
        simulatePaste()
    }

    func clearHistory() {
        items.removeAll()
    }

    // MARK: — Settings observation

    private func observeMaxItems() {
        withObservationTracking {
            _ = SettingsStore.shared.clipboardMaxItems
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                let max = SettingsStore.shared.clipboardMaxItems
                self.source.maxItems = max > 0 ? max : Int.max
                if max > 0 { self.trim(to: max) }
                self.observeMaxItems()
            }
        }
    }

    // MARK: — Private helpers

    private func append(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        let max = SettingsStore.shared.clipboardMaxItems
        if max > 0, items.count > max {
            items.removeLast(items.count - max)
        }
    }

    private func trim(to max: Int) {
        guard items.count > max else { return }
        items.removeLast(items.count - max)
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

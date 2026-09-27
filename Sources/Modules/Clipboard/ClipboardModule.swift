import AppKit
import ApplicationServices
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
    /// Vrai quand l'élément a bien été préparé mais que macOS bloque la frappe ⌘V simulée.
    private(set) var pasteRequiresAccessibility = false

    @ObservationIgnored private let source = ClipboardSource()
    @ObservationIgnored private let historyStore = ClipboardHistoryStore()

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
        if SettingsStore.shared.clipboardPersistEnabled {
            items = Self.orderedForDisplay(historyStore.load())
        }
        let max = SettingsStore.shared.clipboardMaxItems
        source.maxItems = max > 0 ? max : Int.max
        source.onNewItem = { [weak self] item in
            guard let self else { return }
            Task { @MainActor in self.append(item) }
        }
        source.start()
        if max > 0 { trim(to: max) }
        observeSettings()
    }

    public func stop() {
        source.stop()
    }

    // MARK: — Public API

    func paste(item: ClipboardItem) {
        writeToPasteboard(item)
        guard AXIsProcessTrusted() else {
            pasteRequiresAccessibility = true
            return
        }
        pasteRequiresAccessibility = false
        simulatePaste()
    }

    public func pasteLatest() {
        guard let first = items.first else { return }
        paste(item: first)
    }

    func clearHistory() {
        items.removeAll()
        // Toujours effacer le fichier, même si la persistance est désormais désactivée :
        // une session précédente peut avoir laissé un historique sur disque.
        historyStore.clear()
    }

    /// Toggles the pinned state of `item`. Pinned items are kept first in the list
    /// and are never removed when the history is trimmed to `clipboardMaxItems`.
    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        items = Self.orderedForDisplay(items)
        if SettingsStore.shared.clipboardPersistEnabled {
            historyStore.save(items)
        }
    }

    // MARK: — Settings observation

    private func observeSettings() {
        withObservationTracking {
            _ = SettingsStore.shared.clipboardMaxItems
            _ = SettingsStore.shared.clipboardPersistEnabled
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                let max = SettingsStore.shared.clipboardMaxItems
                self.source.maxItems = max > 0 ? max : Int.max
                if max > 0 { self.trim(to: max) }
                if SettingsStore.shared.clipboardPersistEnabled {
                    self.historyStore.save(self.items)
                } else {
                    self.historyStore.clear()
                }
                self.observeSettings()
            }
        }
    }

    // MARK: — Private helpers

    private func append(_ item: ClipboardItem) {
        items.append(item)
        items = Self.orderedForDisplay(items)
        let max = SettingsStore.shared.clipboardMaxItems
        if max > 0 { trim(to: max) }
        if SettingsStore.shared.clipboardPersistEnabled {
            historyStore.save(items)
        }
    }

    /// Removes the oldest non-pinned items until at most `max` non-pinned items remain.
    /// Pinned items never count toward the limit and are never removed here.
    private func trim(to max: Int) {
        let unpinnedCount = items.filter { !$0.isPinned }.count
        guard unpinnedCount > max else { return }
        var overflow = unpinnedCount - max
        for index in items.indices.reversed() where overflow > 0 {
            guard !items[index].isPinned else { continue }
            items.remove(at: index)
            overflow -= 1
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
        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    /// Les épinglés restent en tête ; chaque groupe conserve l'ordre du plus récent au plus ancien.
    static func orderedForDisplay(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.date > rhs.date
        }
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

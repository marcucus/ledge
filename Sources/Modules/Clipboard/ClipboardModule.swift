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

    /// Échec de persistance visible et récupérable (doc 13, Jalon 2, point 12) : la capture en
    /// RAM continue normalement, seul le disque est en cause. `nil` = pas de problème en cours.
    /// Passe par `SettingsStore` (voir `ClipboardPersistenceIssue`) plutôt qu'un état local, car
    /// `ClipboardModuleSettingsView` est construite par `ModuleCatalog` sans connaître l'instance
    /// du module en cours d'exécution.
    public var persistenceIssue: ClipboardPersistenceIssue? { settings.clipboardPersistenceIssue }

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let source: ClipboardSource
    @ObservationIgnored private let historyStore: ClipboardHistoryStore
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var observationGeneration = 0

    /// nonisolated(unsafe) so deinit (non-isolated) can reach it
    @ObservationIgnored private nonisolated(unsafe) var _source: ClipboardSource

    public convenience init() {
        self.init(settings: .shared, source: ClipboardSource(), historyStore: ClipboardHistoryStore())
    }

    init(settings: SettingsStore, source: ClipboardSource, historyStore: ClipboardHistoryStore) {
        self.settings = settings
        self.source = source
        self.historyStore = historyStore
        _source = source
    }

    deinit {
        _source.stop()
    }

    // MARK: — NotchModule

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        observationGeneration += 1
        if settings.clipboardPersistEnabled {
            loadPersistedHistory()
        }
        let max = settings.clipboardMaxItems
        source.maxItems = max > 0 ? max : Int.max
        source.excludedBundleIdentifiers = Set(settings.clipboardExcludedApps)
        source.onNewItem = { [weak self] item in
            guard let self else { return }
            Task { @MainActor in self.append(item) }
        }
        source.start()
        if max > 0 { trim(to: max) }
        observeSettings(generation: observationGeneration)
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        observationGeneration += 1
        source.stop()
        source.onNewItem = nil
    }

    // MARK: — Capture marketing

    /// Injecte un historique de démonstration sans passer par `ClipboardSource` (pas
    /// d'observation réelle du presse-papiers système) — utilisé uniquement par
    /// `MarketingCapture` (cf. docs/PLAN-REFONTE-FIDELITE.md). `items` est `private(set)` en
    /// interne à ce fichier : cette méthode doit donc vivre ici, dans la même cible.
    package func configureMarketingCapture(items: [ClipboardItem]) {
        self.items = Self.orderedForDisplay(items)
    }

    // MARK: — Public API

    /// `asPlainText` correspond au ⌘+clic du mockup (doc 03) : force une copie du texte brut
    /// sur le presse-papiers système, sans le type `.URL` qui ferait ré-interpréter un lien
    /// (auto-complétion, aperçu…) par l'app cible.
    func paste(item: ClipboardItem, asPlainText: Bool = false) {
        writeToPasteboard(item, asPlainText: asPlainText)
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
        clearPersistedHistory()
    }

    /// Toggles the pinned state of `item`. Pinned items are kept first in the list
    /// and are never removed when the history is trimmed to `clipboardMaxItems`.
    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        items = Self.orderedForDisplay(items)
        persist(items)
    }

    // MARK: — Settings observation

    /// Réagit à tout changement pertinent de `SettingsStore` — y compris le jeton de
    /// `requestClipboardPersistenceRetry()` : bumper ce jeton depuis
    /// `ClipboardModuleSettingsView` retombe donc ici et retente exactement le même
    /// persist/clear que celui qui avait échoué, sans code de retry dédié.
    private func observeSettings(generation: Int) {
        withObservationTracking {
            _ = settings.clipboardMaxItems
            _ = settings.clipboardPersistEnabled
            _ = settings.clipboardPersistenceRetryToken
            _ = settings.clipboardExcludedApps
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.isStarted, self.observationGeneration == generation else { return }
                let max = self.settings.clipboardMaxItems
                self.source.maxItems = max > 0 ? max : Int.max
                self.source.excludedBundleIdentifiers = Set(self.settings.clipboardExcludedApps)
                if max > 0 { self.trim(to: max) }
                if self.settings.clipboardPersistEnabled {
                    if self.settings.clipboardPersistenceIssue == .loadFailed {
                        self.loadPersistedHistory()
                    } else {
                        self.persist(self.items)
                    }
                } else {
                    self.clearPersistedHistory()
                }
                self.observeSettings(generation: generation)
            }
        }
    }

    // MARK: — Private helpers

    private func append(_ item: ClipboardItem) {
        items.append(item)
        items = Self.orderedForDisplay(items)
        let max = settings.clipboardMaxItems
        if max > 0 { trim(to: max) }
        persist(items)
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

    /// Écrit l'historique sur disque si la persistance est activée ; sinon ne fait rien (l'appel
    /// reste sûr même si l'utilisateur vient de désactiver l'option). Efface `persistenceIssue`
    /// dès qu'une écriture réussit.
    private func persist(_ items: [ClipboardItem]) {
        guard settings.clipboardPersistEnabled else { return }
        do {
            try historyStore.save(items)
            settings.clipboardPersistenceIssue = nil
        } catch {
            settings.clipboardPersistenceIssue = .saveFailed
        }
    }

    private func loadPersistedHistory() {
        do {
            items = Self.orderedForDisplay(try historyStore.load())
            settings.clipboardPersistenceIssue = nil
        } catch {
            settings.clipboardPersistenceIssue = .loadFailed
        }
    }

    private func clearPersistedHistory() {
        do {
            try historyStore.clear()
            if settings.clipboardPersistenceIssue == .clearFailed {
                settings.clipboardPersistenceIssue = nil
            }
        } catch {
            settings.clipboardPersistenceIssue = .clearFailed
        }
    }

    private func writeToPasteboard(_ item: ClipboardItem, asPlainText: Bool) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch item.content {
        case let .text(text):
            pasteboard.setString(text, forType: .string)
        case let .url(url):
            pasteboard.setString(url.absoluteString, forType: .string)
            if !asPlainText {
                pasteboard.setString(url.absoluteString, forType: .URL)
            }
        case let .image(img):
            // Pas de représentation textuelle possible : "texte brut" laisse le presse-papiers
            // vide plutôt que de coller l'image malgré la demande explicite de l'utilisateur.
            if !asPlainText, let tiff = img.tiffRepresentation {
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

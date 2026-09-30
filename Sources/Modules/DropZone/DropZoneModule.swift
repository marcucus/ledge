import AppKit
import Core
import SwiftUI

@MainActor
@Observable
public final class DropZoneModule: NotchModule {
    public let id = "dropzone"
    public let tabIcon = "tray.and.arrow.down"
    public let tabLabel: LocalizedStringKey = "module.dropzone.label"

    public private(set) var items: [ShelfItem] = []
    public private(set) var lastCopyFailureCount = 0
    public var isDragActive = false {
        didSet { updateAmbient() }
    }

    public var onAmbientUpdate: ((AmbientContent?) -> Void)?
    @ObservationIgnored private var isStarted = false

    public init() {}

    // MARK: — NotchModule

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        updateAmbient()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        isDragActive = false
        onAmbientUpdate?(nil)
    }
    public func makePeekView() -> AnyView {
        AnyView(DropZonePeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(DropZoneContentView(module: self))
    }

    // MARK: — Capture marketing

    /// Injecte des éléments de démonstration directement dans l'état observable — utilisé
    /// uniquement par `MarketingCapture` (cf. docs/PLAN-REFONTE-FIDELITE.md). Contrairement aux
    /// autres modules, `ShelfItem.isAvailable` dépend du système de fichiers réel : l'appelant
    /// doit fournir des `URL` pointant vers des fichiers temporaires réellement présents sur
    /// disque au moment de la capture (voir `main.swift`), sans quoi les items apparaîtront
    /// indisponibles à l'écran.
    package func configureMarketingCapture(items: [ShelfItem]) {
        self.items = items
    }

    // MARK: — Shelf operations

    public func addURLs(_ urls: [URL]) {
        let filtered: [URL]
        if SettingsStore.shared.dropZoneAcceptFolders {
            filtered = urls
        } else {
            filtered = urls.filter { url in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                return !isDir.boolValue
            }
        }
        for url in filtered {
            guard !items.contains(where: { $0.url == url }) else { continue }
            items.append(ShelfItem(url: url))
        }
        updateAmbient()
    }

    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
        updateAmbient()
    }

    public func clearAll() {
        items.removeAll()
        updateAmbient()
    }

    // MARK: — Ambient

    private func updateAmbient() {
        guard isStarted else {
            onAmbientUpdate?(nil)
            return
        }
        if isDragActive || !items.isEmpty {
            onAmbientUpdate?(.init(kind: .dropzone(count: items.count), accentColor: .blue))
        } else {
            onAmbientUpdate?(nil)
        }
    }

    // MARK: — AirDrop

    public func shareViaAirDrop(from view: NSView) {
        let urls = items.filter(\.isAvailable).map(\.url)
        guard !urls.isEmpty else { return }
        let picker = NSSharingServicePicker(items: urls)
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    // MARK: — Save to folder

    public func saveAllToFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = NSLocalizedString("dropzone.action.save", bundle: localizationBundle, comment: "")
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            Task { @MainActor in
                await self.copyItems(to: destination)
            }
        }
    }

    private func copyItems(to destination: URL) async {
        let fileManager = FileManager.default
        var failureCount = 0
        for item in items where item.isAvailable {
            let dest = uniqueDestination(for: item.displayName, in: destination, fileManager: fileManager)
            do {
                try fileManager.copyItem(at: item.url, to: dest)
            } catch {
                failureCount += 1
            }
        }
        failureCount += items.filter { !$0.isAvailable }.count
        lastCopyFailureCount = failureCount
    }

    /// Évite un échec silencieux quand un fichier du même nom existe déjà à destination :
    /// ajoute un suffixe numéroté à la façon du Finder ("nom 2.ext", "nom 3.ext", …) jusqu'à
    /// trouver un nom libre, plutôt que de laisser `copyItem` échouer et compter une collision
    /// de nom comme une vraie erreur de copie.
    /// Accès `internal` (plutôt que `private`) pour rester testable via `@testable import`.
    func uniqueDestination(for displayName: String, in destination: URL, fileManager: FileManager) -> URL {
        var candidate = destination.appendingPathComponent(displayName)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let baseName = (displayName as NSString).deletingPathExtension
        let fileExtension = (displayName as NSString).pathExtension
        var suffix = 2
        repeat {
            let newName = fileExtension.isEmpty ? "\(baseName) \(suffix)" : "\(baseName) \(suffix).\(fileExtension)"
            candidate = destination.appendingPathComponent(newName)
            suffix += 1
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }
}

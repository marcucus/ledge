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
    public private(set) var isCopying = false
    public private(set) var copiedItemCount = 0
    public private(set) var copyItemCount = 0
    public var isDragActive = false {
        didSet { updateAmbient() }
    }

    public var onAmbientUpdate: ((AmbientContent?) -> Void)?
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let fileCopier: any DropZoneCopying
    @ObservationIgnored private var copyTask: Task<Void, Never>?

    public init(settings: SettingsStore = .shared) {
        self.settings = settings
        fileCopier = DropZoneFileCopier()
    }

    init(settings: SettingsStore = .shared, fileCopier: any DropZoneCopying) {
        self.settings = settings
        self.fileCopier = fileCopier
    }

    // MARK: — NotchModule

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        updateAmbient()
    }

    public func stop() {
        guard isStarted else { return }
        cancelCopy()
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
        if settings.dropZoneAcceptFolders {
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
        cancelCopy()
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
                self.beginCopy(to: destination)
            }
        }
    }

    func beginCopy(to destination: URL) {
        cancelCopy()
        copyTask = Task { @MainActor [weak self] in
            await self?.copyItems(to: destination)
        }
    }

    public func cancelCopy() {
        copyTask?.cancel()
        copyTask = nil
    }

    var copyProgress: Double {
        guard copyItemCount > 0 else { return 0 }
        return Double(copiedItemCount) / Double(copyItemCount)
    }

    func copyItems(to destination: URL) async {
        let requests = items.compactMap { item -> DropZoneCopyRequest? in
            guard item.isAvailable else { return nil }
            return DropZoneCopyRequest(sourceURL: item.url, displayName: item.displayName)
        }
        var failureCount = items.count - requests.count
        copyItemCount = items.count
        copiedItemCount = 0
        lastCopyFailureCount = 0
        isCopying = !items.isEmpty
        defer {
            lastCopyFailureCount = failureCount
            isCopying = false
            copyTask = nil
        }

        for request in requests {
            guard !Task.isCancelled else { break }
            let didCopy = await fileCopier.copy(request, to: destination)
            copiedItemCount += 1
            if !didCopy { failureCount += 1 }
        }
    }
}

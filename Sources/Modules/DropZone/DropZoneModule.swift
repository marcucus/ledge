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
    public var isDragActive = false {
        didSet { updateAmbient() }
    }

    public var onAmbientUpdate: ((AmbientContent?) -> Void)?

    public init() {}

    // MARK: — NotchModule

    public func start() {}
    public func stop() {}
    public func makePeekView() -> AnyView {
        AnyView(DropZonePeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(DropZoneContentView(module: self))
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
        if isDragActive || !items.isEmpty {
            onAmbientUpdate?(.init(kind: .dropzone(count: items.count), accentColor: .blue))
        } else {
            onAmbientUpdate?(nil)
        }
    }

    // MARK: — AirDrop

    public func shareViaAirDrop(from view: NSView) {
        let urls = items.map(\.url)
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
        for item in items {
            let dest = destination.appendingPathComponent(item.displayName)
            try? fileManager.copyItem(at: item.url, to: dest)
        }
    }
}

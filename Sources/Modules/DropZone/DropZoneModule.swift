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
    public private(set) var isDragActive = false

    nonisolated(unsafe) private var globalDragMonitor: Any?

    public init() {}

    // MARK: — NotchModule

    public func start() {}
    public func stop() { stopMonitoringDrags() }
    public func makePeekView() -> AnyView { AnyView(DropZonePeekView(module: self)) }
    public func makeContentView() -> AnyView { AnyView(DropZoneContentView(module: self)) }

    deinit {
        globalDragMonitor.map { NSEvent.removeMonitor($0) }
    }

    // MARK: — Global drag detection

    public func startMonitoringDrags(near notchWindow: NSWindow) {
        guard globalDragMonitor == nil else { return }
        globalDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self, weak notchWindow] _ in
            guard let self, let window = notchWindow else { return }
            let mouseLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            let expandedFrame = windowFrame.insetBy(dx: -40, dy: -60)
            Task { @MainActor in
                self.isDragActive = expandedFrame.contains(mouseLocation)
            }
        }
    }

    public func stopMonitoringDrags() {
        globalDragMonitor.map { NSEvent.removeMonitor($0) }
        globalDragMonitor = nil
        isDragActive = false
    }

    // MARK: — Shelf operations

    public func addURLs(_ urls: [URL]) {
        for url in urls {
            guard !items.contains(where: { $0.url == url }) else { continue }
            items.append(ShelfItem(url: url))
        }
    }

    public func removeItem(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func clearAll() {
        items.removeAll()
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
        panel.prompt = NSLocalizedString("dropzone.action.save", comment: "")
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

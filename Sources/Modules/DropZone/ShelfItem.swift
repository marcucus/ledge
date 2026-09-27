import AppKit

public struct ShelfItem: Identifiable {
    public let id: UUID
    public let url: URL
    public let displayName: String
    public var icon: NSImage?
    public var isAvailable: Bool { FileManager.default.fileExists(atPath: url.path) }

    public init(url: URL) {
        id = UUID()
        self.url = url
        displayName = url.lastPathComponent
        icon = NSWorkspace.shared.icon(forFile: url.path)
    }
}

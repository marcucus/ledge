import AppKit

public struct ShelfItem: Identifiable {
    public let id: UUID
    public let url: URL
    public let displayName: String
    public var icon: NSImage?

    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.displayName = url.lastPathComponent
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }
}

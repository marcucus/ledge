import AppKit
import Foundation

// MARK: — Content types

/// The content stored for a clipboard history entry.
public enum ClipboardContent {
    case text(String)
    case url(URL)
    /// Stores a thumbnail (max 128×128) to keep memory usage low.
    case image(NSImage)
}

// MARK: — Item

/// A single entry in the clipboard history.
public struct ClipboardItem: Identifiable {
    public let id: UUID
    public let content: ClipboardContent
    public let date: Date

    public init(id: UUID = UUID(), content: ClipboardContent, date: Date = Date()) {
        self.id = id
        self.content = content
        self.date = date
    }
}

// MARK: — Helpers

extension ClipboardContent {
    /// Short description used in PeekView and accessibility labels.
    /// Note: the `.image` case returns a constant key — the view layer
    /// is responsible for passing it through `LocalizedStringKey` if needed.
    var previewText: String {
        switch self {
        case .text(let s):  return String(s.prefix(80))
        case .url(let u):   return u.absoluteString
        case .image:        return "clipboard.item.image"  // treated as key by the views
        }
    }
}

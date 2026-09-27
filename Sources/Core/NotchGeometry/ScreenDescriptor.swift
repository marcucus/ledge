import AppKit
import CoreGraphics

public struct ScreenDescriptor: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isBuiltIn: Bool
    public let hasNotch: Bool
    public let width: Int
    public let height: Int

    init(screen: NSScreen) {
        id = screen.ledgeIdentifier
        name = screen.localizedName
        isBuiltIn = screen.ledgeDisplayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
        hasNotch = screen.hasNotch
        width = Int(screen.frame.width)
        height = Int(screen.frame.height)
    }
}

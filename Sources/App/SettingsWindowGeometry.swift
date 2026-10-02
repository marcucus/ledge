import AppKit

enum SettingsWindowGeometry {
    static let minimumContentSize = NSSize(width: 720, height: 520)

    static func normalizedContentSize(_ size: NSSize) -> NSSize {
        NSSize(
            width: max(size.width, minimumContentSize.width),
            height: max(size.height, minimumContentSize.height)
        )
    }

    static func constrainedFrame(_ frame: NSRect, to visibleFrame: NSRect) -> NSRect {
        var result = frame
        result.size.width = min(result.width, visibleFrame.width)
        result.size.height = min(result.height, visibleFrame.height)
        result.origin.x = min(max(result.minX, visibleFrame.minX), visibleFrame.maxX - result.width)
        result.origin.y = min(max(result.minY, visibleFrame.minY), visibleFrame.maxY - result.height)
        return result
    }
}

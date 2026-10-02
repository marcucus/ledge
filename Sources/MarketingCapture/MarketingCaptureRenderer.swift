import AppKit
import SwiftUI

/// Rend les vues SwiftUI de marketing avec leurs véritables sous-vues AppKit, hors écran.
enum MarketingCaptureRenderer {
    /// `ImageRenderer` remplace certains contrôles AppKit (TextEditor, champs de recherche,
    /// ScrollView) par un symbole d'échec. Un véritable `NSHostingView` les restitue fidèlement.
    @MainActor
    static func renderPNG<Content: View>(view: Content, size: CGSize, name: String) throws -> Data {
        let scale = 2
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * scale,
            pixelsHigh: Int(size.height) * scale,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw CaptureError.renderFailed(name)
        }
        bitmap.size = size
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CaptureError.renderFailed(name)
        }
        return png
    }
}

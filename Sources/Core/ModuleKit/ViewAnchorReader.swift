import AppKit
import SwiftUI

/// Capture la véritable `NSView` hôte d'une vue SwiftUI, pour ancrer des API AppKit
/// (`NSSharingServicePicker`, `NSMenu`, etc.) qui exigent une vue concrète plutôt que la
/// fenêtre clé. Indispensable dans Ledge : `NotchWindow` est un panneau non activable
/// (`.nonactivatingPanel`) qui ne devient jamais `NSApplication.shared.keyWindow`, donc
/// toute logique basée sur `keyWindow?.contentView` échoue silencieusement.
private struct ViewAnchorReader: NSViewRepresentable {
    let onUpdate: (NSView) -> Void

    func makeNSView(context _: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context _: Context) {
        // `nsView` est dimensionnée par SwiftUI comme le fond de la vue hôte (voir `anchorNSView`),
        // donc son `bounds` reflète déjà la vue qu'on veut ancrer. On évite de modifier l'état
        // pendant le cycle de mise à jour SwiftUI en différant l'appel.
        DispatchQueue.main.async { onUpdate(nsView) }
    }
}

public extension View {
    /// Pose une vue AppKit invisible en fond de `self` et rappelle `perform` avec la `NSView`
    /// réelle dès qu'elle est disponible, puis à chaque mise à jour de layout. À utiliser comme
    /// ancre pour une API AppKit manuelle (picker de partage, menu…) plutôt que
    /// `NSApplication.shared.keyWindow`, qui ne fonctionne pas avec un panneau non activable.
    func anchorNSView(_ perform: @escaping (NSView) -> Void) -> some View {
        background(ViewAnchorReader(onUpdate: perform))
    }
}

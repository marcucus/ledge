import AppKit
import QuickLookUI
import SwiftUI

/// Enveloppe AppKit autour de `QLPreviewView` pour afficher un aperçu QuickLook en SwiftUI.
/// Se dégrade silencieusement vers `nil` si l'aperçu ne peut pas être généré — l'appelant
/// affiche alors l'icône système du fichier à la place (jamais de crash).
private struct QuickLookPreviewRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = url as QLPreviewItem
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        guard nsView.previewItem?.previewItemURL != url else { return }
        nsView.previewItem = url as QLPreviewItem
    }
}

/// Aperçu agrandi d'un fichier : tente QuickLook, retombe sur l'icône système en cas d'échec.
public struct QuickLookPreview: View {
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        QuickLookPreviewRepresentable(url: url)
            .frame(width: 220, height: 220)
            .background(fallbackIcon)
    }

    /// Icône système affichée en fond : visible uniquement quand QuickLook ne rend rien.
    private var fallbackIcon: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding(40)
    }
}

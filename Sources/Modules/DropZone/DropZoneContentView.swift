import AppKit
import Core
import SwiftUI
import UniformTypeIdentifiers

public struct DropZoneContentView: View {
    public var module: DropZoneModule

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 8)]

    /// Ancre réelle de la barre d'actions, capturée via `anchorNSView` (voir `ViewAnchorReader`).
    /// Remplace `NSApplication.shared.keyWindow?.contentView`, invalide ici car `NotchWindow`
    /// est un panneau non activable qui ne devient jamais la fenêtre clé.
    @State private var actionBarAnchorView: NSView?

    public init(module: DropZoneModule) {
        self.module = module
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dropZoneArea
            if unavailableCount > 0 {
                unavailableWarning
            }
            if module.lastCopyFailureCount > 0 {
                copyFailureWarning
            }
            if !module.items.isEmpty {
                actionBar
            }
        }
        .padding(12)
    }

    private var unavailableCount: Int {
        module.items.filter { !$0.isAvailable }.count
    }

    private var unavailableWarning: some View {
        warningLabel(key: "dropzone.unavailable.count", count: unavailableCount)
    }

    private var copyFailureWarning: some View {
        warningLabel(key: "dropzone.copy.failed.count", count: module.lastCopyFailureCount)
    }

    private func warningLabel(key: String, count: Int) -> some View {
        Label {
            Text(
                String(
                    format: NSLocalizedString(key, bundle: localizationBundle, comment: ""),
                    count
                )
            )
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .font(.caption)
        .foregroundStyle(.orange)
    }

    // MARK: — Drop zone

    private var dropZoneArea: some View {
        Group {
            if module.items.isEmpty {
                emptyState
            } else {
                itemGrid
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    module.isDragActive ? Color.accentColor : Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1.5, dash: [5])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: Binding(
            get: { module.isDragActive },
            set: { _ in }
        )) { providers in
            handleDrop(providers: providers)
        }
    }

    private var emptyState: some View {
        ModuleEmptyState(
            icon: "tray.and.arrow.down",
            titleKey: "dropzone.empty",
            detailKey: "dropzone.empty.detail"
        )
    }

    private var itemGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(module.items) { item in
                ShelfItemView(item: item) {
                    module.removeItem(id: item.id)
                }
            }
        }
        .padding(8)
    }

    // MARK: — Action bar

    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton(label: "dropzone.action.airdrop", icon: "airplayaudio") {
                guard let view = actionBarAnchorView else { return }
                module.shareViaAirDrop(from: view)
            }
            actionButton(label: "dropzone.action.save", icon: "folder") {
                module.saveAllToFolder()
            }
            Spacer()
            actionButton(label: "dropzone.action.clear", icon: "trash", isDestructive: true) {
                module.clearAll()
            }
        }
        .anchorNSView { actionBarAnchorView = $0 }
    }

    private func actionButton(
        label: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(LocalizedStringKey(label), bundle: localizationBundle)
            } icon: {
                Image(systemName: icon)
            }
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDestructive ? .red.opacity(0.8) : .secondary)
    }

    // MARK: — Drop handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    module.addURLs([url])
                }
            }
            handled = true
        }
        return handled
    }
}

// MARK: — Shelf item tile

private struct ShelfItemView: View {
    let item: ShelfItem
    let onRemove: () -> Void

    /// Délai avant l'apparition de l'aperçu QuickLook, annulé si le survol s'arrête avant.
    @State private var hoverPreviewTask: Task<Void, Never>?
    @State private var isPreviewVisible = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                iconView
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .accessibilityLabel(Text("dropzone.action.remove", bundle: localizationBundle))
            }
            Text(item.displayName)
                .font(.system(size: 9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64)
        .draggable(item.url)
        .help(item.displayName)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.displayName)
        .onHover(perform: handleHover)
        .popover(isPresented: $isPreviewVisible, arrowEdge: .top) {
            QuickLookPreview(url: item.url)
                .padding(12)
        }
        .onDisappear { hoverPreviewTask?.cancel() }
        // L'aperçu ne dépendait que du survol — inutilisable au clavier ou avec VoiceOver
        // (doc 13, Jalon 4, item 24). `.focusable()` + Espace reproduit le raccourci Quick
        // Look standard du Finder ; l'action nommée offre le même bascule via le rotor
        // VoiceOver, qui n'intercepte pas toujours les frappes clavier brutes.
        .focusable(item.isAvailable)
        .onKeyPress(.space) {
            guard item.isAvailable else { return .ignored }
            isPreviewVisible.toggle()
            return .handled
        }
        .accessibilityAction(named: Text("dropzone.action.preview", bundle: localizationBundle)) {
            guard item.isAvailable else { return }
            isPreviewVisible.toggle()
        }
    }

    private var iconView: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let icon = item.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "doc")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .opacity(item.isAvailable ? 1 : 0.35)
            if !item.isAvailable {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .frame(width: 40, height: 40)
    }

    /// Programme l'ouverture de l'aperçu après un court délai, annulé si le survol cesse
    /// ou change de cible avant l'expiration (pattern collapseTask/hudTask de NotchController).
    private func handleHover(isHovering: Bool) {
        hoverPreviewTask?.cancel()
        guard isHovering, item.isAvailable else {
            isPreviewVisible = false
            return
        }
        hoverPreviewTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            isPreviewVisible = true
        }
    }
}

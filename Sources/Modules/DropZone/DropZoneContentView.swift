import Core
import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct DropZoneContentView: View {
    public var module: DropZoneModule

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 8)]

    public init(module: DropZoneModule) {
        self.module = module
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dropZoneArea
            if !module.items.isEmpty {
                actionBar
            }
        }
        .padding(12)
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
        VStack(spacing: 6) {
            Image(systemName: "tray.and.arrow.down")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text("dropzone.empty", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
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
                guard let view = findNSView() else { return }
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
                    self.module.addURLs([url])
                }
            }
            handled = true
        }
        return handled
    }

    // Finds the underlying NSView to anchor NSSharingServicePicker
    private func findNSView() -> NSView? {
        NSApplication.shared.keyWindow?.contentView
    }
}

// MARK: — Shelf item tile

private struct ShelfItemView: View {
    let item: ShelfItem
    let onRemove: () -> Void

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
            }
            Text(item.displayName)
                .font(.system(size: 9))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(width: 64)
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
    }

    private var iconView: some View {
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
        .frame(width: 40, height: 40)
    }
}

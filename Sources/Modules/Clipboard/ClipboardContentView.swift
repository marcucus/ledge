import AppKit
import SwiftUI

// MARK: — ClipboardContentView

struct ClipboardContentView: View {
    var module: ClipboardModule

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.4)
            itemList
        }
    }

    // MARK: — Toolbar

    private var toolbar: some View {
        HStack {
            Text("module.clipboard.label")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                module.clearHistory()
            } label: {
                Label("clipboard.action.clear", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: — Item list

    @ViewBuilder
    private var itemList: some View {
        if module.items.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(module.items) { item in
                        ClipboardRowView(item: item) {
                            module.paste(item: item)
                        }
                        Divider().opacity(0.2)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .imageScale(.large)
                .foregroundStyle(.tertiary)
            Text("clipboard.empty")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: — ClipboardRowView

private struct ClipboardRowView: View {
    let item: ClipboardItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                icon
                    .frame(width: 20)
                preview
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: — Icon

    @ViewBuilder
    private var icon: some View {
        switch item.content {
        case .text:
            Image(systemName: "doc.text")
                .imageScale(.small)
                .foregroundStyle(.secondary)
        case .url:
            Image(systemName: "link")
                .imageScale(.small)
                .foregroundStyle(.blue)
        case .image(let img):
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    // MARK: — Preview text

    @ViewBuilder
    private var preview: some View {
        if case .image = item.content {
            // Use localized key for image label
            Text("clipboard.item.image")
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        } else {
            Text(item.content.previewText)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)
        }
    }

    // MARK: — Date

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.date, relativeTo: Date())
    }
}

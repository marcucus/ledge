import AppKit
import Core
import SwiftUI

// MARK: — ClipboardContentView

struct ClipboardContentView: View {
    var module: ClipboardModule

    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            searchField
            Divider().opacity(0.4)
            itemList
        }
    }

    // MARK: — Displayed items

    /// `module.items` filtered by `searchText` (when non-empty) with pinned items first,
    /// then the rest ordered newest to oldest (as already provided by the module).
    private var displayedItems: [ClipboardItem] {
        let filtered = filteredItems
        let pinned = filtered.filter(\.isPinned)
        let unpinned = filtered.filter { !$0.isPinned }
        return pinned + unpinned
    }

    private var filteredItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return module.items }
        return module.items.filter { item in
            switch item.content {
            case .text, .url:
                item.content.previewText.localizedCaseInsensitiveContains(searchText)
            case .image:
                false
            }
        }
    }

    // MARK: — Toolbar

    private var toolbar: some View {
        HStack {
            Text("module.clipboard.label", bundle: localizationBundle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                module.clearHistory()
            } label: {
                Label {
                    Text("clipboard.action.clear", bundle: localizationBundle)
                } icon: {
                    Image(systemName: "trash")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: — Search field

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            TextField(
                "clipboard.search.placeholder",
                text: $searchText,
                prompt: Text("clipboard.search.placeholder", bundle: localizationBundle)
            )
            .textFieldStyle(.plain)
            .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    // MARK: — Item list

    @ViewBuilder
    private var itemList: some View {
        if displayedItems.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(displayedItems) { item in
                        ClipboardRowView(item: item) {
                            module.paste(item: item)
                        } onTogglePin: {
                            module.togglePin(item)
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
            Text("clipboard.empty", bundle: localizationBundle)
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
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 10) {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            pinButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    // MARK: — Pin button

    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .imageScale(.small)
                .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .help(
            item.isPinned
                ? Text("clipboard.action.unpin", bundle: localizationBundle)
                : Text("clipboard.action.pin", bundle: localizationBundle)
        )
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
        case let .image(img):
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
            Text("clipboard.item.image", bundle: localizationBundle)
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

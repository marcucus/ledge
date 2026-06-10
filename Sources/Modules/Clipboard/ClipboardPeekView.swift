import SwiftUI

// MARK: — ClipboardPeekView

/// Compact view shown in the notch peek (hover) state.
/// Displays the most-recently copied item, or an icon when history is empty.
struct ClipboardPeekView: View {
    var module: ClipboardModule

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            if let latest = module.items.first {
                clipboardPreviewText(latest.content)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            } else {
                Text("clipboard.empty")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
    }

    // MARK: — Helpers

    /// Returns a localized Text for clipboard content preview.
    @ViewBuilder
    private func clipboardPreviewText(_ content: ClipboardContent) -> some View {
        switch content {
        case .image:
            Text("clipboard.item.image")  // LocalizedStringKey lookup
        default:
            Text(content.previewText)     // plain string (url or truncated text)
        }
    }
}

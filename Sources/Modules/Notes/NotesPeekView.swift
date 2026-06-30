import Core
import SwiftUI

// MARK: — NotesPeekView

/// Compact view shown in the notch peek (hover) state.
/// Displays a truncated preview of the note, or an icon when empty.
struct NotesPeekView: View {
    var module: NotesModule

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "note.text")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            if preview.isEmpty {
                Text("notes.empty", bundle: localizationBundle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text(preview)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 8)
        .frame(maxHeight: .infinity)
    }

    // MARK: — Preview text

    /// First line of the note, truncated to ~40 characters.
    private var preview: String {
        let firstLine = module.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first ?? ""
        let limit = 40
        if firstLine.count > limit {
            return String(firstLine.prefix(limit)) + "…"
        }
        return String(firstLine)
    }
}

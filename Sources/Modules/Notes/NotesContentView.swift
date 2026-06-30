import Core
import SwiftUI

// MARK: — NotesContentView

struct NotesContentView: View {
    var module: NotesModule

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.4)
            editor
        }
    }

    // MARK: — Toolbar

    private var toolbar: some View {
        HStack {
            Text("module.notes.label", bundle: localizationBundle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                module.clear()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(Text("notes.action.clear", bundle: localizationBundle))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: — Editor

    private var editor: some View {
        TextEditor(text: Binding(get: { module.text }, set: { module.text = $0 }))
            .scrollContentBackground(.hidden)
            .font(.callout)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(alignment: .topLeading) {
                if module.text.isEmpty {
                    Text("notes.placeholder", bundle: localizationBundle)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
    }
}

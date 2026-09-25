import Core
import SwiftUI

public struct ShortcutsContentView: View {
    public var module: ShortcutsModule

    private let maxDisplayed = 20

    public init(module: ShortcutsModule) {
        self.module = module
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider().opacity(0.4)
            shortcutList
        }
        .padding(12)
    }

    // MARK: — Header

    private var header: some View {
        HStack {
            Text("module.shortcuts.label", bundle: localizationBundle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await module.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .imageScale(.small)
                    .rotationEffect(.degrees(module.isLoading ? 360 : 0))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("shortcuts.action.refresh", bundle: localizationBundle))
        }
    }

    // MARK: — List

    @ViewBuilder
    private var shortcutList: some View {
        if module.isLoading && module.shortcuts.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("shortcuts.loading", bundle: localizationBundle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if module.shortcuts.isEmpty {
            ModuleEmptyState(
                icon: "square.stack.3d.up.slash",
                titleKey: "shortcuts.empty",
                detailKey: "shortcuts.empty.detail",
                actionKey: "shortcuts.action.refresh"
            ) {
                Task { await module.refresh() }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(module.shortcuts.prefix(maxDisplayed), id: \.self) { name in
                        ShortcutRowView(name: name, module: module)
                    }
                }
            }
        }
    }
}

// MARK: — Row

private struct ShortcutRowView: View {
    let name: String
    let module: ShortcutsModule

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.footnote)
                .lineLimit(1)
            Spacer()
            Button {
                module.run(name)
            } label: {
                Image(systemName: "play.fill")
                    .imageScale(.small)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(Text("shortcuts.action.run", bundle: localizationBundle))
        }
        .padding(.vertical, 2)
    }
}

import Core
import SwiftUI

struct ShortcutRowView: View {
    let name: String
    let module: ShortcutsModule

    @State private var isHovered = false

    private var isRunning: Bool { module.runningShortcutName == name }
    private var didSucceed: Bool { module.lastRunSucceededName == name }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                module.run(name)
            } label: {
                HStack(spacing: 10) {
                    shortcutIcon
                    Text(name)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    statusIcon
                }
                .padding(.leading, 8)
                .frame(minHeight: 42)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(module.runningShortcutName != nil)
            .help(name)
            .accessibilityLabel(name)
            .accessibilityHint(Text("shortcuts.action.run", bundle: localizationBundle))

            Button {
                module.toggleFavorite(name)
            } label: {
                Image(systemName: module.isFavorite(name) ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(module.isFavorite(name) ? Color.yellow : .secondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(Text(favoriteActionKey, bundle: localizationBundle))
            .accessibilityLabel(Text(favoriteActionKey, bundle: localizationBundle))
            .padding(.trailing, 4)
        }
        .background(rowBackground)
        .onHover { isHovered = $0 }
    }

    private var favoriteActionKey: LocalizedStringKey {
        module.isFavorite(name) ? "shortcuts.action.unfavorite" : "shortcuts.action.favorite"
    }

    private var shortcutIcon: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 28, height: 28)
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if isRunning {
            ProgressView()
                .controlSize(.mini)
                .frame(width: 28, height: 28)
                .accessibilityLabel(Text("shortcuts.status.running", bundle: localizationBundle))
        } else if didSucceed {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 28, height: 28)
                .accessibilityLabel(Text("shortcuts.status.completed", bundle: localizationBundle))
        } else {
            Image(systemName: "play.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isHovered ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(isHovered ? 0.08 : 0.045), in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(isRunning ? Color.accentColor.opacity(0.08) : Color.white.opacity(isHovered ? 0.04 : 0))
    }
}

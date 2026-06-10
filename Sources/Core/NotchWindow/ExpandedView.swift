import SwiftUI

struct ExpandedView: View {
    var controller: NotchController

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().opacity(0.4)
            contentArea
        }
    }

    // MARK: — Barre d'onglets

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ModuleTab.allCases) { tab in
                moduleTabButton(tab)
            }
            Spacer()
            iconButton(icon: "gear", label: "action.settings") {
                // Ouvre les Paramètres — V4
            }
            iconButton(icon: "xmark", label: "action.close") {
                controller.dismiss()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: Layout.tabBarHeight)
    }

    private func moduleTabButton(_ tab: ModuleTab) -> some View {
        Button {
            // Sélection de module — V1
        } label: {
            Image(systemName: tab.icon)
                .imageScale(.medium)
                .frame(width: 36, height: Layout.tabBarHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
    }

    private func iconButton(
        icon: String,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: Layout.tabBarHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: — Zone de contenu

    // Remplie par les modules dès V1
    private var contentArea: some View {
        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: — Onglets

private enum ModuleTab: String, CaseIterable, Identifiable {
    case media, clipboard, system, timers

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .media:     "music.note"
        case .clipboard: "doc.on.clipboard"
        case .system:    "cpu"
        case .timers:    "timer"
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .media:     "module.media.label"
        case .clipboard: "module.clipboard.label"
        case .system:    "module.system.label"
        case .timers:    "module.timers.label"
        }
    }
}

// MARK: — Constantes

private enum Layout {
    static let tabBarHeight: CGFloat = 44
}

import SwiftUI

/// Barre de navigation toujours visible (peek + expanded).
/// Gauche : icônes des catégories / Droite : statut (batterie…) + paramètres.
struct NavBar: View {
    var controller: NotchController
    @AppStorage("preferredLanguage") private var language: String = "system"

    var body: some View {
        HStack(spacing: 0) {
            // Catégories à gauche
            HStack(spacing: 0) {
                ForEach(controller.visibleModules.map(ModuleItem.init), id: \.id) { item in
                    ModuleTabButton(
                        item: item,
                        isSelected: item.id == controller.selectedModuleID,
                        showLabel: controller.showModuleLabels
                    ) {
                        controller.selectModule(id: item.id)
                    }
                }
            }
            .padding(.leading, 6)

            Spacer()

            // Statut à droite (batterie uniquement)
            if let status = controller.statusModule {
                status.makePeekView().id(language)
            }

            // Bouton fermer (seulement en expanded)
            if controller.state == .expanded {
                iconButton(icon: "xmark") { controller.dismiss() }
            }

            // Bouton paramètres
            iconButton(icon: "gear") { controller.openSettings?() }
                .padding(.trailing, 6)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private func iconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Tab button avec hover

private struct ModuleTabButton: View {
    let item: ModuleItem
    let isSelected: Bool
    let showLabel: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: item.base.tabIcon)
                    .imageScale(.medium)
                    .foregroundStyle(isSelected ? .primary : (isHovered ? .secondary : .tertiary))
                if showLabel {
                    Text(item.base.tabLabel)
                        .font(.system(size: 9, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(isSelected ? .primary : .tertiary)
                }
            }
            .frame(width: 34, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(
                        isSelected ? 0.14 : (isHovered ? 0.07 : 0)
                    ))
                    .padding(.horizontal, 2)
                    .padding(.vertical, 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.base.tabLabel)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

// MARK: —

@MainActor
private struct ModuleItem {
    let id: String
    let base: any NotchModule
    init(_ module: any NotchModule) {
        id = module.id; base = module
    }
}

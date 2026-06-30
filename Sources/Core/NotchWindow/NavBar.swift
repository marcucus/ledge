import SwiftUI

/// Barre de navigation toujours visible (peek + expanded).
/// Gauche : icônes des catégories / Droite : statut (batterie…) + paramètres.
struct NavBar: View {
    var controller: NotchController
    @AppStorage("preferredLanguage") private var language: String = "system"

    /// Largeur d'un onglet (frame 30 + espacement 2).
    private let tabWidth: CGFloat = 32

    /// Largeur réservée au centre : encoche physique + une marge de chaque côté pour que les
    /// onglets voisins ne passent pas sous l'encoche (légèrement plus large que la valeur brute).
    private var notchReserve: CGFloat {
        controller.notchWidth + 24
    }

    /// Répartit les onglets autour de l'encoche : autant que la zone gauche peut en contenir,
    /// le surplus passe à droite de l'encoche (collé à l'encoche), avant batterie + réglages.
    private var moduleSplit: (left: [ModuleItem], right: [ModuleItem]) {
        let items = controller.visibleModules.map(ModuleItem.init)
        let leftZone = (controller.expandedWidth - notchReserve) / 2 - 10
        let maxLeft = max(1, Int(leftZone / tabWidth))
        guard items.count > maxLeft else { return (items, []) }
        return (Array(items.prefix(maxLeft)), Array(items.suffix(items.count - maxLeft)))
    }

    var body: some View {
        let split = moduleSplit
        return HStack(spacing: 0) {
            // Zone gauche : premiers onglets
            HStack(spacing: 2) {
                ForEach(split.left, id: \.id) { tabButton($0) }
            }
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Encoche physique (+ marge) : largeur réservée au centre.
            Color.clear.frame(width: notchReserve)

            // Zone droite : onglets en surplus (collés à l'encoche) + batterie/réglages (au bord)
            HStack(spacing: 0) {
                HStack(spacing: 2) {
                    ForEach(split.right, id: \.id) { tabButton($0) }
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    if let status = controller.statusModule {
                        status.makePeekView().id(language)
                    }
                    iconButton(icon: "gear") { controller.openSettings?() }
                }
            }
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(_ item: ModuleItem) -> some View {
        ModuleTabButton(
            item: item,
            isSelected: item.id == controller.selectedModuleID
        ) {
            controller.selectModule(id: item.id)
        }
    }

    private func iconButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 28, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Tab button avec hover

private struct ModuleTabButton: View {
    let item: ModuleItem
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: item.base.tabIcon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(isSelected ? 1 : (isHovered ? 0.85 : 0.6)))
                .frame(width: 30, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.16 : (isHovered ? 0.08 : 0)))
                        .padding(.horizontal, 2)
                        .padding(.vertical, 5)
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

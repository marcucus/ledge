import SwiftUI

/// Barre de navigation toujours visible (peek + expanded).
/// Gauche : icônes des catégories / Droite : statut (batterie…) + paramètres.
struct NavBar: View {
    var controller: NotchController
    @AppStorage("preferredLanguage") private var language: String = "system"

    private var tabWidth: CGFloat {
        switch controller.panelComposition {
        case .focused: 40
        case .panoramic: 48
        case .immersive: 44
        }
    }

    /// Largeur réservée au centre : encoche physique + une marge de chaque côté pour que les
    /// onglets voisins ne passent pas sous l'encoche (légèrement plus large que la valeur brute).
    private var notchReserve: CGFloat {
        controller.notchWidth + 24
    }

    /// Garde les onglets groupés à gauche tant qu'ils tiennent sur l'épaule de l'encoche.
    /// Seul le surplus passe à droite, avant la batterie et les réglages.
    private var moduleSplit: (left: [ModuleItem], right: [ModuleItem]) {
        let items = controller.navigationModules.map(ModuleItem.init)
        let leadingCount = NavigationModuleLayout.leadingModuleCount(
            moduleCount: items.count,
            panelWidth: controller.expandedWidth,
            notchReserve: notchReserve,
            tabWidth: tabWidth,
            showsGridButton: controller.showsModuleGrid
        )
        return (Array(items.prefix(leadingCount)), Array(items.dropFirst(leadingCount)))
    }

    var body: some View {
        let split = moduleSplit
        return HStack(spacing: 0) {
            // Zone gauche : premiers onglets
            HStack(spacing: 2) {
                if controller.showsModuleGrid {
                    ModuleLauncherButton(
                        modules: controller.gridModules,
                        selectedModuleID: controller.activeModuleID,
                        width: tabWidth,
                        height: controller.navigationHeight,
                        accentColor: controller.appAccentColor,
                        onSelect: controller.selectModule(id:),
                        onPresentationChange: controller.setTransientInteractionActive(_:)
                    )
                }
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
                    SettingsNavigationButton(height: controller.navigationHeight) {
                        controller.openSettings?()
                    }
                }
            }
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity)
        }
        .frame(height: controller.navigationHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 14)
        }
    }

    private func tabButton(_ item: ModuleItem) -> some View {
        ModuleTabButton(
            item: item,
            isSelected: item.id == controller.activeModuleID,
            width: tabWidth,
            height: controller.navigationHeight,
            accentColor: controller.appAccentColor
        ) {
            controller.selectModule(id: item.id)
        }
    }

}

// MARK: — Tab button avec hover

private struct ModuleTabButton: View {
    let item: ModuleItem
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    let accentColor: Color
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            NavigationTabLabel(
                icon: item.base.tabIcon,
                isSelected: isSelected,
                isHovered: isHovered,
                width: width,
                height: height,
                accentColor: accentColor
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(item.base.tabLabel)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
    }

}

struct NavigationTabLabel: View {
    let icon: String
    let isSelected: Bool
    let isHovered: Bool
    let width: CGFloat
    let height: CGFloat
    let accentColor: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(.white.opacity(isSelected ? 1 : (isHovered ? 0.85 : 0.58)))
            .frame(width: width, height: height)
            .background(selectionBackground)
    }

    private var selectionBackground: some View {
        ZStack(alignment: .bottom) {
            Color.white.opacity(isSelected ? 0.08 : (isHovered ? 0.04 : 0))
            Capsule()
                .fill(isSelected ? accentColor : .clear)
                .frame(width: 16, height: 2)
                .padding(.bottom, 4)
        }
    }
}

private struct SettingsNavigationButton: View {
    let height: CGFloat
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.62))
                .frame(width: 36, height: height)
                .background(Color.white.opacity(isHovered ? 0.045 : 0))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(Text("action.settings", bundle: localizationBundle))
        .accessibilityLabel(Text("action.settings", bundle: localizationBundle))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isHovered)
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

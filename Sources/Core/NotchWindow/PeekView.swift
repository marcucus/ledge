import SwiftUI

struct PeekView: View {
    var controller: NotchController

    var body: some View {
        HStack(spacing: 0) {
            // Icônes des modules à gauche
            HStack(spacing: 2) {
                ForEach(controller.modules.map(ModuleItem.init), id: \.id) { item in
                    Button { controller.selectModule(id: item.id) } label: {
                        Image(systemName: item.base.tabIcon)
                            .imageScale(.small)
                            .foregroundStyle(item.id == controller.selectedModuleID ? .primary : .tertiary)
                            .frame(width: 26, height: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Contenu peek du module sélectionné (ex: batterie %, média en cours)
            if let module = controller.selectedModule {
                module.makePeekView()
            }

            // Bouton paramètres
            Button { controller.openSettings?() } label: {
                Image(systemName: "gear")
                    .imageScale(.small)
                    .foregroundStyle(.tertiary)
                    .frame(width: 26, height: 44)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 44)
        .frame(maxWidth: .infinity)
    }
}

@MainActor
private struct ModuleItem {
    let id: String
    let base: any NotchModule
    init(_ module: any NotchModule) { id = module.id; base = module }
}

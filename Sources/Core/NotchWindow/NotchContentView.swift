import SwiftUI

struct NotchContentView: View {
    var controller: NotchController
    private var state: NotchState { controller.state }
    @AppStorage("preferredLanguage") private var language: String = "system"

    var body: some View {
        VStack(spacing: 0) {
            // Navbar au niveau de l'encoche physique
            NavBar(controller: controller)
                .frame(height: controller.notchHeight)
                .frame(maxWidth: .infinity)
                .opacity(state != .collapsed ? 1 : 0)

            // Séparateur + contenu du module (expanded seulement)
            if state == .expanded {
                Divider().opacity(0.3)
                Group {
                    if let module = controller.selectedModule {
                        module.makeContentView()
                    } else {
                        Color.clear
                    }
                }
                .id("\(controller.selectedModuleID)-\(language)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background)
        .animation(.easeOut(duration: state == .expanded ? 0.12 : 0.08).delay(state == .expanded ? 0.28 : 0), value: state)
        .colorScheme(.dark)
    }

    @ViewBuilder
    private var background: some View {
        if state != .collapsed {
            Color.black
                .clipShape(NotchPanelShape(
                    topEar:        12,
                    bottomRadius:  state == .expanded ? 12 : 10
                ))
                .animation(.easeOut(duration: 0.15), value: state)
        }
    }
}

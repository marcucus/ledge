import SwiftUI

struct NotchContentView: View {
    var controller: NotchController
    private var state: NotchState { controller.state }
    @AppStorage("preferredLanguage") private var language: String = "system"

    var body: some View {
        VStack(spacing: 0) {
            // La NavBar part de y=0 (même niveau que le sommet de l'encoche physique).
            // Elle fait 44 px ; les ~20 px inférieurs dépassent sous l'encoche et sont visibles.
            if state == .hud {
                if let hud = controller.hudContent {
                    HUDBar(content: hud, notchHeight: controller.notchHeight)
                }
            } else if state != .collapsed {
                NavBar(controller: controller)
            }

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

// MARK: — HUD bar (volume / luminosité)
// Barre fine centrée dans la zone visible sous l'encoche (pas d'icône).

struct HUDBar: View {
    let content: HUDContent
    let notchHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 28
            let barWidth = max(0, geo.size.width - inset * 2)
            // Centre la barre dans l'espace sous l'encoche
            let barY = notchHeight + (geo.size.height - notchHeight) / 2
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.20))
                    .frame(width: barWidth, height: 5)
                Capsule()
                    .fill(content.tint)
                    .frame(width: barWidth * max(0.01, content.value), height: 5)
            }
            .position(x: geo.size.width / 2, y: barY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

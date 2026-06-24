import SwiftUI

struct NotchContentView: View {
    var controller: NotchController
    private var state: NotchState {
        controller.state
    }

    @AppStorage("preferredLanguage") private var language: String = "system"

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // La NavBar part de y=0 (même niveau que le sommet de l'encoche physique).
                // Elle fait 44 px ; les ~20 px inférieurs dépassent sous l'encoche et sont visibles.
                if state == .hud {
                    if let hud = controller.hudContent {
                        HUDBar(content: hud, notchHeight: controller.notchHeight)
                    }
                } else if state == .ambient {
                    AmbientView(controller: controller)
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
            .padding(.horizontal, (state == .collapsed || state == .ambient) ? 0 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(background)
            // Ouverture : contenu apparaît 0.28 s après le début (pendant que la fenêtre s'agrandit).
            // Fermeture : la fenêtre se rétracte avec un fond noir — l'animation SwiftUI est couverte,
            //             on la laisse courte pour éviter toute artefact visible.
            .animation(
                .easeOut(duration: state == .expanded ? 0.12 : 0.06).delay(state == .expanded ? 0.28 : 0),
                value: state
            )
            .colorScheme(.dark)

            // Ring timer
            if state == .collapsed {
                TimerRingView(controller: controller)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        Color.black
            .opacity(state == .collapsed ? 0 : controller.panelBackgroundOpacity)
            .clipShape(NotchPanelShape(
                topEar: state == .collapsed ? 0 : 12,
                bottomRadius: state == .expanded ? controller.panelCornerRadius : 10
            ))
            .animation(.easeOut(duration: 0.15), value: state)
    }
}

// MARK: — HUD bar (volume / luminosité)

struct HUDBar: View {
    let content: HUDContent
    let notchHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let cy = notchHeight + (geo.size.height - notchHeight) * 0.5
            HStack(spacing: 10) {
                Image(systemName: content.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22)

                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    GeometryReader { bar in
                        let fillColor = content.isMuted ? Color.white.opacity(0.4) : content.tint
                        let w = bar.size.width * max(0.01, content.value)
                        Capsule()
                            .fill(fillColor)
                            .frame(width: w)
                            .shadow(color: fillColor.opacity(0.9), radius: 6)
                            .shadow(color: fillColor.opacity(0.5), radius: 12)
                            .animation(.easeOut(duration: 0.10), value: content.value)
                    }
                }
                .frame(height: 6)

                Group {
                    if content.isMuted {
                        Text("Muted")
                    } else {
                        Text("\(Int(content.value * 100))%").monospacedDigit()
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .frame(width: geo.size.width, height: 28)
            .position(x: geo.size.width / 2, y: cy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: — Timer ring

struct TimerRingView: View {
    let controller: NotchController

    var body: some View {
        if controller.timerRingActive {
            TimelineView(.animation) { (ctx: TimelineViewDefaultContext) in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let alpha = 0.5 + 0.4 * sin(t * .pi * 0.8)
                NotchPanelShape(topEar: 0, bottomRadius: 10)
                    .stroke(controller.appAccentColor.opacity(alpha), lineWidth: 1.5)
                    .padding(.horizontal, NotchController.timerRingInset)
                    .padding(.bottom, NotchController.timerRingInset)
            }
        }
    }
}

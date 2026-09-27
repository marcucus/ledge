import SwiftUI

struct NotchContentView: View {
    var controller: NotchController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

                if state == .expanded && controller.isExpansionSettled {
                    Group {
                        if let module = controller.selectedModule {
                            module.makeContentView()
                        } else {
                            Color.clear
                        }
                    }
                    .id("\(controller.activeModuleID)-\(language)")
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, controller.panelComposition == .immersive ? 8 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .environment(\.panelComposition, controller.panelComposition)
                    .transition(contentTransition)
                }
            }
            .padding(.horizontal, outerHorizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(background)
            // Le masque porte sur toute la hiérarchie, pas seulement sur le fond. Certains
            // modules dessinent leur propre noir ; sans ce clip ils recouvrent les quatre coins.
            .clipShape(panelShape)
            // La sortie conserve la transition historique. Le signal `isExpansionSettled`
            // n'ajoute qu'une révélation à l'entrée, après le redimensionnement AppKit.
            .animation(
                reduceMotion || state == .expanded
                    ? nil
                    : .spring(response: 0.42, dampingFraction: 0.88),
                value: state
            )
            .animation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: 0.18),
                value: controller.isExpansionSettled
            )
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.9),
                       value: controller.panelComposition)
            .colorScheme(.dark)

            // Ring timer
            if state == .collapsed {
                TimerRingView(controller: controller)
            }
        }
    }

    private var outerHorizontalPadding: CGFloat {
        guard state != .collapsed, state != .ambient else { return 0 }
        return controller.panelComposition == .focused ? 10 : 14
    }

    private var contentHorizontalPadding: CGFloat {
        switch controller.panelComposition {
        case .focused: 0
        case .panoramic: 8
        case .immersive: 16
        }
    }

    private var contentTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity.combined(with: .offset(y: -6))
    }

    @ViewBuilder
    private var background: some View {
        Color.black
            .opacity(state == .collapsed ? 0 : controller.panelBackgroundOpacity)
            // À l'ouverture, AppKit possède seul le mouvement géométrique. À la fermeture,
            // on restaure l'interpolation du masque qui produisait la résorption d'origine.
            .animation(
                reduceMotion || state == .expanded
                    ? nil
                    : .spring(response: 0.4, dampingFraction: 0.9),
                value: state
            )
    }

    private var panelShape: NotchPanelShape {
        NotchPanelShape(
            topEar: state == .collapsed ? 0 : effectiveTopEar,
            bottomRadius: state == .expanded ? controller.panelCornerRadius : 10
        )
    }

    /// Ambient, HUD et peek sont des états universels : leur silhouette ne dépend jamais de la
    /// composition du panneau ouvert. La géométrie compacte est la référence commune.
    private var effectiveTopEar: CGFloat {
        guard state == .expanded else { return 10 }
        return topEar
    }

    private var topEar: CGFloat {
        switch controller.panelComposition {
        case .focused: 10
        case .panoramic: 18
        case .immersive: 14
        }
    }
}

// MARK: — HUD bar (volume / luminosité)

struct HUDBar: View {
    let content: HUDContent
    let notchHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let centerY = notchHeight + (geo.size.height - notchHeight) * 0.5
            HStack(spacing: 10) {
                Image(systemName: content.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22)

                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    GeometryReader { bar in
                        let fillColor = content.isMuted ? Color.white.opacity(0.4) : content.tint
                        let fillWidth = bar.size.width * max(0.01, content.value)
                        Capsule()
                            .fill(fillColor)
                            .frame(width: fillWidth)
                            .shadow(color: fillColor.opacity(0.9), radius: 6)
                            .shadow(color: fillColor.opacity(0.5), radius: 12)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.10), value: content.value)
                    }
                }
                .frame(height: 6)

                Group {
                    if content.isMuted {
                        Text("hud.muted", bundle: localizationBundle)
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
            .position(x: geo.size.width / 2, y: centerY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(
                content.kind == .volume ? "hud.accessibility.volume" : "hud.accessibility.brightness",
                bundle: localizationBundle
            )
        )
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        if content.isMuted {
            return Text("hud.muted", bundle: localizationBundle)
        }
        return Text("\(Int(content.value * 100))%")
    }
}

// MARK: — Timer ring

struct TimerRingView: View {
    let controller: NotchController
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if controller.timerRingActive {
            if reduceMotion {
                ring(alpha: 0.8)
            } else {
                TimelineView(.animation) { (context: TimelineViewDefaultContext) in
                    let elapsed = context.date.timeIntervalSinceReferenceDate
                    ring(alpha: 0.5 + 0.4 * sin(elapsed * .pi * 0.8))
                }
            }
        }
    }

    private func ring(alpha: Double) -> some View {
        NotchPanelShape(topEar: 0, bottomRadius: 10)
            .stroke(controller.appAccentColor.opacity(alpha), lineWidth: 1.5)
            .padding(.horizontal, NotchController.timerRingInset)
            .padding(.bottom, NotchController.timerRingInset)
    }
}

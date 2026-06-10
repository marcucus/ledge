import SwiftUI

struct NotchContentView: View {
    var controller: NotchController

    private var isExpanded: Bool { controller.state == .expanded }

    var body: some View {
        ZStack(alignment: .top) {
            // Panneau noir : ancré en haut (notch), s'étend vers le bas
            Color.black
                .clipShape(UnevenRoundedRectangle(
                    bottomLeadingRadius: isExpanded ? 12 : 10,
                    bottomTrailingRadius: isExpanded ? 12 : 10
                ))
                .frame(
                    width: isExpanded ? 560 : controller.notchWidth,
                    height: isExpanded ? controller.notchHeight + 300 : controller.notchHeight
                )
                .animation(
                    isExpanded
                        ? .easeOut(duration: 0.25)   // en sync avec NSAnimationContext
                        : .easeOut(duration: 0.22),
                    value: controller.state
                )

            // Contenu qui apparaît une fois la forme formée
            ExpandedView(controller: controller)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isExpanded ? 1 : 0)
                .allowsHitTesting(isExpanded)
                .animation(
                    isExpanded
                        ? .easeOut(duration: 0.1).delay(0.15)
                        : .easeIn(duration: 0.06),
                    value: controller.state
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .colorScheme(.dark)
    }
}

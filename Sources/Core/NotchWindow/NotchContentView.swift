import SwiftUI

struct NotchContentView: View {
    var controller: NotchController

    var body: some View {
        Group {
            switch controller.state {
            case .collapsed:
                Color.clear
            case .peeking:
                PeekView(controller: controller)
            case .expanded:
                ExpandedView(controller: controller)
            }
        }
        .background(.regularMaterial)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: Layout.cornerRadius,
                bottomTrailingRadius: Layout.cornerRadius
            )
        )
        .animation(.easeInOut(duration: 0.2), value: controller.state)
    }
}

private enum Layout {
    // Rayon qui prolonge visuellement le coin de l'encoche physique
    static let cornerRadius: CGFloat = 10
}

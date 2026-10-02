import SwiftUI

/// Façade interne donnant à la cible `MarketingCapture` accès à la véritable hiérarchie du
/// panneau sans rendre `NotchContentView` publique pour les intégrateurs du package.
package struct MarketingCaptureView: View {
    private let controller: NotchController

    package init(controller: NotchController) {
        self.controller = controller
    }

    package var body: some View {
        NotchContentView(controller: controller)
    }
}

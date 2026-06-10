import SwiftUI

struct PeekView: View {
    var controller: NotchController

    var body: some View {
        if let module = controller.selectedModule {
            module.makePeekView()
        } else {
            defaultPeek
        }
    }

    private var defaultPeek: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle").imageScale(.small).foregroundStyle(.secondary)
            Text("notch.app.name").font(.callout.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

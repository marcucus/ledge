import SwiftUI

struct PeekView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkle")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text("notch.app.name")
                .font(.callout.weight(.medium))
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

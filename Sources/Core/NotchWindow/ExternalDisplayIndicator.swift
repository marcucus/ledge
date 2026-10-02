import SwiftUI

struct ExternalDisplayIndicator: View {
    static let width: CGFloat = 104
    static let height: CGFloat = 7

    var body: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.black)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
            }
            .frame(width: Self.width, height: 12)
            .offset(y: -5)
            .frame(width: Self.width, height: Self.height, alignment: .top)
            .clipped()
            .accessibilityHidden(true)
    }
}

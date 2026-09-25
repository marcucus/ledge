import Core
import SwiftUI

struct PermissionRow: View {
    let icon: String
    let nameKey: LocalizedStringKey
    let detailKey: LocalizedStringKey
    let state: PermissionAccessState
    let actionKey: LocalizedStringKey?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(nameKey, bundle: localizationBundle)
                    .font(.body.weight(.medium))
                Text(detailKey, bundle: localizationBundle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 7) {
                Label {
                    Text(state.labelKey, bundle: localizationBundle)
                } icon: {
                    Image(systemName: state.icon)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(state.color)

                if let actionKey, let action {
                    Button(action: action) {
                        Text(actionKey, bundle: localizationBundle)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

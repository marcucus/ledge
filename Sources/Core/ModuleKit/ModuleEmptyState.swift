import SwiftUI

public struct ModuleEmptyState: View {
    private let icon: String
    private let titleKey: LocalizedStringKey
    private let detailKey: LocalizedStringKey
    private let actionKey: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        icon: String,
        titleKey: LocalizedStringKey,
        detailKey: LocalizedStringKey,
        actionKey: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.titleKey = titleKey
        self.detailKey = detailKey
        self.actionKey = actionKey
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(titleKey, bundle: localizationBundle)
                .font(.callout.weight(.semibold))
            Text(detailKey, bundle: localizationBundle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionKey, let action {
                Button(action: action) {
                    Text(actionKey, bundle: localizationBundle)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

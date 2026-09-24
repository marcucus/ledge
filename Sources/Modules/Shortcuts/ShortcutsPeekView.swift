import Core
import SwiftUI

public struct ShortcutsPeekView: View {
    public var module: ShortcutsModule

    public init(module: ShortcutsModule) {
        self.module = module
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .imageScale(.medium)
                .foregroundStyle(Color.accentColor)
            if module.shortcuts.isEmpty {
                Text("shortcuts.empty", bundle: localizationBundle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(module.shortcuts.count)")
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

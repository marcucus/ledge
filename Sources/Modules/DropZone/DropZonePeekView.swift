import Core
import SwiftUI

public struct DropZonePeekView: View {
    public var module: DropZoneModule

    public init(module: DropZoneModule) {
        self.module = module
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: module.isDragActive ? "arrow.down.to.line" : "tray.and.arrow.down")
                .imageScale(.small)
                .foregroundStyle(module.isDragActive ? Color.accentColor : Color.secondary)
                .animation(.easeInOut(duration: 0.15), value: module.isDragActive)

            if module.items.isEmpty {
                Text("dropzone.empty", bundle: localizationBundle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(module.items.count)")
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("dropzone.items.count", bundle: localizationBundle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}

import Core
import SwiftUI

struct PanelCompositionPreview: View {
    var store: SettingsStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                previewGround
                panel(in: geometry.size)
            }
        }
        .frame(height: 118)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.88),
                   value: store.panelComposition)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("settings.appearance.preview.accessibility", bundle: localizationBundle))
    }

    private var previewGround: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.black.opacity(0.9))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.top, 18)
            }
    }

    private func panel(in size: CGSize) -> some View {
        let dimensions = previewDimensions(in: size)
        return VStack(spacing: 0) {
            notchRail(width: dimensions.width)
            if store.panelComposition != .focused {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: dimensions.width - 28, height: 1)
            }
            contentHint(width: dimensions.width, height: dimensions.height - 28)
        }
        .frame(width: dimensions.width, height: dimensions.height, alignment: .top)
        .background(Color.black)
        .clipShape(NotchPanelShape(topEar: 8, bottomRadius: store.cornerRadius * 0.35))
        .overlay {
            NotchPanelShape(topEar: 8, bottomRadius: store.cornerRadius * 0.35)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
        }
        .offset(y: 3)
    }

    private func notchRail(width: CGFloat) -> some View {
        let visibleModules = Array(previewBarModules.prefix(4))
        let splitIndex = (visibleModules.count + 1) / 2
        let leftModules = visibleModules.prefix(splitIndex)
        let rightModules = visibleModules.dropFirst(splitIndex)

        return HStack(spacing: 8) {
            if store.showsModuleGrid(in: store.panelComposition) {
                previewIcon("circle.grid.3x3.fill", isActive: false)
            }
            ForEach(leftModules) { entry in
                previewIcon(entry.icon, isActive: entry.id == "media")
            }
            Spacer(minLength: 46)
            ForEach(rightModules) { entry in
                previewIcon(entry.icon, isActive: entry.id == "media")
            }
            previewIcon("gearshape", isActive: false)
        }
        .padding(.horizontal, 12)
        .frame(width: width, height: 28)
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.black)
                .frame(width: 44, height: 16)
        }
    }

    private var previewBarModules: [ModuleCatalog.Entry] {
        let entriesByID: [String: ModuleCatalog.Entry] = Dictionary(
            uniqueKeysWithValues: ModuleCatalog.entries.map { ($0.id, $0) }
        )
        return store.moduleOrder(in: store.panelComposition).compactMap { id in
            guard id != "system",
                  let entry = entriesByID[id],
                  store.modulePlacement(id, in: store.panelComposition) == .bar
            else { return nil }
            return entry
        }
    }

    private func previewIcon(_ name: String, isActive: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(isActive ? Color.purple : Color.white.opacity(0.55))
    }

    @ViewBuilder
    private func contentHint(width: CGFloat, height: CGFloat) -> some View {
        if store.panelComposition == .immersive {
            Rectangle()
                .fill(Color.purple.opacity(0.24))
                .frame(width: width, height: height * 0.48)
            controlLines(width: width)
        } else {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.purple.opacity(0.28))
                    .frame(width: height * 0.68, height: height * 0.68)
                controlLines(width: width * 0.48)
            }
            .frame(height: height)
        }
    }

    private func controlLines(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule().fill(Color.white.opacity(0.8)).frame(width: width * 0.52, height: 3)
            Capsule().fill(Color.white.opacity(0.28)).frame(width: width * 0.34, height: 2)
            Capsule().fill(Color.purple.opacity(0.8)).frame(width: width * 0.72, height: 2)
        }
        .frame(width: width, alignment: .leading)
    }

    private func previewDimensions(in size: CGSize) -> CGSize {
        switch store.panelComposition {
        case .focused:
            CGSize(width: min(size.width * 0.48, 250), height: 78)
        case .panoramic:
            CGSize(width: min(size.width * 0.82, 430), height: 88)
        case .immersive:
            CGSize(width: min(size.width * 0.62, 330), height: 108)
        }
    }
}

struct PanelCompositionPicker: View {
    var store: SettingsStore

    var body: some View {
        HStack(spacing: 10) {
            ForEach(PanelComposition.allCases, id: \.rawValue) { composition in
                PanelCompositionButton(
                    composition: composition,
                    isSelected: store.panelComposition == composition
                ) {
                    store.panelComposition = composition
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PanelCompositionButton: View {
    let composition: PanelComposition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if composition == .panoramic {
                        Text("settings.appearance.composition.recommended", bundle: localizationBundle)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(nameKey, bundle: localizationBundle)
                    .font(.system(size: 12, weight: .semibold))
                Text(descriptionKey, bundle: localizationBundle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .padding(10)
            .background(background)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(isSelected ? 0.1 : 0.035))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                            lineWidth: isSelected ? 1.5 : 0.5)
            }
    }

    private var icon: String {
        switch composition {
        case .focused: "rectangle.compress.vertical"
        case .panoramic: "rectangle.expand.vertical"
        case .immersive: "photo.on.rectangle.angled"
        }
    }

    private var nameKey: LocalizedStringKey {
        switch composition {
        case .focused: "settings.appearance.composition.focused"
        case .panoramic: "settings.appearance.composition.panoramic"
        case .immersive: "settings.appearance.composition.immersive"
        }
    }

    private var descriptionKey: LocalizedStringKey {
        switch composition {
        case .focused: "settings.appearance.composition.focused.description"
        case .panoramic: "settings.appearance.composition.panoramic.description"
        case .immersive: "settings.appearance.composition.immersive.description"
        }
    }
}

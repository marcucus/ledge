import SwiftUI

@MainActor
struct ModuleLauncherButton: View {
    let modules: [any NotchModule]
    let selectedModuleID: String
    let width: CGFloat
    let height: CGFloat
    let accentColor: Color
    let onSelect: (String) -> Void
    let onPresentationChange: (Bool) -> Void

    @State private var isPresented = false
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActive: Bool {
        isPresented || modules.contains { $0.id == selectedModuleID }
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            NavigationTabLabel(
                icon: "circle.grid.3x3",
                isSelected: isActive,
                isHovered: isHovered,
                width: width,
                height: height,
                accentColor: accentColor
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            launcherContent
        }
        .onChange(of: isPresented) { _, isPresented in
            onPresentationChange(isPresented)
        }
        .accessibilityLabel(Text("moduleLauncher.button", bundle: localizationBundle))
        .accessibilityAddTraits(isPresented ? .isSelected : [])
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isPresented)
    }

    private var launcherContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "circle.grid.3x3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: 28, height: 28)
                    .background(accentColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("moduleLauncher.title", bundle: localizationBundle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("moduleLauncher.subtitle", bundle: localizationBundle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer(minLength: 0)

                Text("\(modules.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 0.5)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(modules.indices, id: \.self) { index in
                    moduleButton(modules[index])
                }
            }
        }
        .padding(14)
        .frame(width: 282)
        .background {
            ZStack {
                Color(red: 0.035, green: 0.041, blue: 0.047)
                LinearGradient(
                    colors: [accentColor.opacity(0.07), .clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private func moduleButton(_ module: any NotchModule) -> some View {
        let isSelected = module.id == selectedModuleID
        return Button {
            onSelect(module.id)
            isPresented = false
        } label: {
            HStack(spacing: 9) {
                Image(systemName: module.tabIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? accentColor : .white.opacity(0.7))
                    .frame(width: 20)
                Text(module.tabLabel, bundle: localizationBundle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.78))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(moduleBackground(isSelected: isSelected))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func moduleBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(isSelected ? accentColor.opacity(0.16) : Color.white.opacity(0.045))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(
                        isSelected ? accentColor.opacity(0.52) : Color.white.opacity(0.07),
                        lineWidth: 0.75
                    )
            }
    }
}

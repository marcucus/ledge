import Core
import SwiftUI

struct AppearanceSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section {
                notchPreview
            }

            Section {
                panelWidthRow
            }

            Section {
                cornerRadiusRow
            }

            Section {
                panelOpacityRow
            }

            Section {
                animationSpeedRow
            }

            Section {
                ThemePresetRow(store: store)
            } header: {
                Text("settings.appearance.themes", bundle: localizationBundle)
            }

            Section {
                hudColorRows
            } header: {
                Text("settings.appearance.accentColor", bundle: localizationBundle)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.appearance", bundle: localizationBundle))
    }

    // MARK: — Preview

    private var notchPreview: some View {
        let scale: CGFloat = 0.20
        let panelW: CGFloat = switch store.panelWidth {
        case .compact: 580
        case .standard: 744
        case .large: 920
        }

        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.06))
                .frame(maxWidth: .infinity)
                .frame(height: 72)

            NotchPanelShape(topEar: 12 * scale, bottomRadius: store.cornerRadius * scale)
                .fill(Color.black)
                .frame(width: panelW * scale, height: 48 * scale)
                .offset(y: -2)
        }
        .animation(.easeOut(duration: 0.2), value: store.cornerRadius)
        .animation(.easeOut(duration: 0.2), value: store.panelWidth)
    }

    // MARK: — Controls

    private var panelWidthRow: some View {
        Picker(selection: Binding(
            get: { store.panelWidth },
            set: { store.panelWidth = $0 }
        )) {
            Text("settings.appearance.panelWidth.compact", bundle: localizationBundle).tag(PanelWidth.compact)
            Text("settings.appearance.panelWidth.standard", bundle: localizationBundle).tag(PanelWidth.standard)
            Text("settings.appearance.panelWidth.large", bundle: localizationBundle).tag(PanelWidth.large)
        } label: {
            Text("settings.appearance.panelWidth", bundle: localizationBundle)
        }
        .pickerStyle(.segmented)
    }

    private var cornerRadiusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.appearance.cornerRadius", bundle: localizationBundle)
            HStack {
                Slider(value: Binding(
                    get: { store.cornerRadius },
                    set: { store.cornerRadius = $0 }
                ), in: 4...24, step: 1)
                Text(String(format: "%.0f pt", store.cornerRadius))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var panelOpacityRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("settings.appearance.panelOpacity", bundle: localizationBundle)
            HStack {
                Slider(value: Binding(
                    get: { store.panelOpacity },
                    set: { store.panelOpacity = $0 }
                ), in: 0.7...1.0, step: 0.01)
                Text(String(format: "%.0f%%", store.panelOpacity * 100))
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var animationSpeedRow: some View {
        Picker(selection: Binding(
            get: { store.animationSpeed },
            set: { store.animationSpeed = $0 }
        )) {
            Text("settings.appearance.animationSpeed.fast", bundle: localizationBundle).tag(AnimationSpeed.fast)
            Text("settings.appearance.animationSpeed.normal", bundle: localizationBundle).tag(AnimationSpeed.normal)
            Text("settings.appearance.animationSpeed.slow", bundle: localizationBundle).tag(AnimationSpeed.slow)
        } label: {
            Text("settings.appearance.animationSpeed", bundle: localizationBundle)
        }
        .pickerStyle(.segmented)
    }

    // MARK: — App accent color

    @ViewBuilder
    private var hudColorRows: some View {
        AccentColorPicker(
            useSystemAccent: Binding(
                get: { store.hudUseSystemAccent },
                set: { store.hudUseSystemAccent = $0 }
            ),
            colorComponents: Binding(
                get: { store.hudAccentColorComponents },
                set: { store.hudAccentColorComponents = $0 }
            )
        )
    }
}

// MARK: — Named theme presets

/// Rangée de cartes de thèmes nommés. Un clic applique couleur + opacité + rayon d'un coup.
private struct ThemePresetRow: View {
    var store: SettingsStore

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Theme.all) { theme in
                ThemeCard(theme: theme, isSelected: store.activeThemeID == theme.id) {
                    store.apply(theme)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    private var accentColor: Color {
        Color(red: theme.accent[0], green: theme.accent[1], blue: theme.accent[2])
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                swatch
                Text(LocalizedStringKey(theme.nameKey), bundle: localizationBundle)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? accentColor : Color.primary.opacity(0.1),
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    /// Aperçu miniature du thème : un panneau dont l'opacité et le rayon reflètent le preset.
    private var swatch: some View {
        RoundedRectangle(cornerRadius: theme.cornerRadius * 0.4)
            .fill(accentColor.opacity(theme.panelOpacity))
            .frame(width: 52, height: 28)
            .overlay(
                Circle()
                    .fill(.white.opacity(0.85))
                    .frame(width: 8, height: 8)
            )
    }
}

// MARK: — Accent color swatch picker

private struct AccentColorPicker: View {
    @Binding var useSystemAccent: Bool
    @Binding var colorComponents: [Double]

    private struct Preset {
        let r, g, b: Double
    }

    private let presets: [Preset] = [
        Preset(r: 1.0,   g: 0.231, b: 0.188), // Red
        Preset(r: 1.0,   g: 0.584, b: 0.0  ), // Orange
        Preset(r: 1.0,   g: 0.800, b: 0.0  ), // Yellow
        Preset(r: 0.196, g: 0.820, b: 0.345), // Green
        Preset(r: 0.0,   g: 0.780, b: 0.745), // Mint
        Preset(r: 0.039, g: 0.518, b: 1.0  ), // Blue
        Preset(r: 0.369, g: 0.361, b: 0.945), // Indigo
        Preset(r: 0.686, g: 0.322, b: 0.871), // Purple
        Preset(r: 1.0,   g: 0.176, b: 0.333), // Pink
        Preset(r: 1.0,   g: 0.420, b: 0.330), // Coral
        Preset(r: 0.984, g: 0.749, b: 0.0  ), // Amber
        Preset(r: 0.188, g: 0.706, b: 0.624), // Teal
        Preset(r: 0.0,   g: 0.792, b: 1.0  ), // Cyan
        Preset(r: 0.745, g: 0.298, b: 0.871), // Violet
    ]

    private var isCustom: Bool {
        !useSystemAccent && !presets.indices.contains(where: { matchesPreset(presets[$0]) })
    }

    private func matchesPreset(_ p: Preset) -> Bool {
        guard colorComponents.count >= 3 else { return false }
        let tol = 0.005
        return abs(colorComponents[0] - p.r) < tol &&
               abs(colorComponents[1] - p.g) < tol &&
               abs(colorComponents[2] - p.b) < tol
    }

    private let columns = Array(repeating: GridItem(.fixed(28), spacing: 8), count: 8)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            // Couleur système
            systemSwatch

            // Presets
            ForEach(presets.indices, id: \.self) { i in
                let p = presets[i]
                ColorSwatch(
                    color: Color(red: p.r, green: p.g, blue: p.b),
                    isSelected: !useSystemAccent && matchesPreset(p)
                ) {
                    useSystemAccent = false
                    colorComponents = [p.r, p.g, p.b]
                }
            }

            // Couleur personnalisée (ouvre le panel natif)
            customSwatch
        }
        .padding(.vertical, 4)
    }

    private var systemSwatch: some View {
        ColorSwatch(color: .accentColor, isSelected: useSystemAccent, isSystem: true) {
            useSystemAccent = true
        }
    }

    private var customSwatch: some View {
        let customColor: Color = colorComponents.count >= 3
            ? Color(red: colorComponents[0], green: colorComponents[1], blue: colorComponents[2])
            : Color.primary.opacity(0.15)

        return ZStack {
            // ColorPicker natif en fond (reçoit les taps)
            ColorPicker("", selection: Binding(
                get: {
                    colorComponents.count >= 3
                        ? Color(red: colorComponents[0], green: colorComponents[1], blue: colorComponents[2])
                        : .gray
                },
                set: { newColor in
                    if let ns = NSColor(newColor).usingColorSpace(.sRGB) {
                        colorComponents = [
                            Double(ns.redComponent),
                            Double(ns.greenComponent),
                            Double(ns.blueComponent),
                        ]
                        useSystemAccent = false
                    }
                }
            ), supportsOpacity: false)
            .labelsHidden()
            .frame(width: 28, height: 28)
            .opacity(0.011) // quasi-invisible mais tappable

            // Visuel du swatch (ne capte pas les taps)
            ZStack {
                Circle()
                    .fill(isCustom ? customColor : Color.primary.opacity(0.08))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )

                if isCustom {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                } else {
                    Image(systemName: "eyedropper")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if isCustom {
                    Circle()
                        .strokeBorder(customColor, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: 28, height: 28)
    }
}

private struct ColorSwatch: View {
    let color: Color
    let isSelected: Bool
    var isSystem: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                    )

                if isSystem {
                    Image(systemName: "s.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 1)
                        .opacity(isSelected ? 0 : 1)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1)
                }

                if isSelected {
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                        .frame(width: 28, height: 28)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

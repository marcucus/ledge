import AppKit
import Core
import SwiftUI

struct DisplaySettingsView: View {
    var store: SettingsStore
    @State private var screens: [ScreenDescriptor] = []

    var body: some View {
        Form {
            Section {
                Picker(selection: targetModeBinding) {
                    Text("settings.display.targetMode.automatic", bundle: localizationBundle)
                        .tag(DisplayTargetMode.automatic)
                    Text("settings.display.targetMode.all", bundle: localizationBundle)
                        .tag(DisplayTargetMode.all)
                    Text("settings.display.targetMode.selected", bundle: localizationBundle)
                        .tag(DisplayTargetMode.selected)
                } label: {
                    Text("settings.display.targetScreen", bundle: localizationBundle)
                }

                if store.displayTargetMode == .selected {
                    screenSelection
                }

                selectionSummary
            } footer: {
                Text("settings.display.targetScreen.hint", bundle: localizationBundle)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker(selection: Binding(
                    get: { store.fullscreenBehavior },
                    set: { store.fullscreenBehavior = $0 }
                )) {
                    Text("settings.display.fullscreen.accessible", bundle: localizationBundle)
                        .tag(FullscreenBehavior.accessible)
                    Text("settings.display.fullscreen.hidden", bundle: localizationBundle)
                        .tag(FullscreenBehavior.hidden)
                    Text("settings.display.fullscreen.overlay", bundle: localizationBundle)
                        .tag(FullscreenBehavior.overlay)
                } label: {
                    Text("settings.display.fullscreen", bundle: localizationBundle)
                }
            }
        }
        .formStyle(.grouped)
        .task { refreshScreens() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in refreshScreens() }
    }

    private var targetModeBinding: Binding<DisplayTargetMode> {
        Binding(
            get: { store.displayTargetMode },
            set: { mode in
                store.displayTargetMode = mode
                if mode == .selected, store.selectedScreenIdentifiers.isEmpty,
                   let defaultScreen = screens.first(where: \.isBuiltIn) ?? screens.first {
                    select(defaultScreen, enabled: true)
                }
            }
        )
    }

    private var screenSelection: some View {
        VStack(spacing: 0) {
            ForEach(screens) { screen in
                Toggle(isOn: selectionBinding(for: screen)) {
                    screenRow(screen)
                }
                .toggleStyle(.checkbox)
                .padding(.vertical, 6)
            }

            ForEach(unavailableSelections, id: \.self) { identifier in
                Toggle(isOn: unavailableSelectionBinding(identifier)) {
                    unavailableRow(identifier)
                }
                .toggleStyle(.checkbox)
                .padding(.vertical, 6)
            }
        }
        .padding(.vertical, 2)
    }

    private func screenRow(_ screen: ScreenDescriptor) -> some View {
        HStack(spacing: 10) {
            Image(systemName: screen.isBuiltIn ? "laptopcomputer" : "display")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(screen.name).font(.body.weight(.medium))
                Text(screenDetail(screen)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(
                screen.hasNotch
                    ? "settings.display.targetScreen.physicalNotch"
                    : "settings.display.targetScreen.simulatedNotch",
                bundle: localizationBundle
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private func unavailableRow(_ identifier: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .foregroundStyle(.orange)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(store.selectedScreenNames[identifier] ?? identifier)
            Spacer()
            Text("settings.display.targetScreen.unavailable", bundle: localizationBundle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var selectionSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: summaryIcon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(summaryTitle).font(.body.weight(.medium))
                Text("settings.display.targetScreen.summary.detail", bundle: localizationBundle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(summaryCount)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var summaryIcon: String {
        store.displayTargetMode == .all ? "rectangle.on.rectangle" : "display"
    }

    private var summaryTitle: String {
        switch store.displayTargetMode {
        case .automatic: localized("settings.display.targetMode.automatic")
        case .all: localized("settings.display.targetMode.all")
        case .selected: localized("settings.display.targetMode.selected")
        }
    }

    private var summaryCount: String {
        let count: Int
        switch store.displayTargetMode {
        case .automatic: count = min(1, screens.count)
        case .all: count = screens.count
        case .selected: count = store.selectedScreenIdentifiers.count
        }
        return String(format: localized("settings.display.targetScreen.count.format"), count)
    }

    private var unavailableSelections: [String] {
        let connected = Set(screens.map(\.id))
        return store.selectedScreenIdentifiers.filter { !connected.contains($0) }
    }

    private func selectionBinding(for screen: ScreenDescriptor) -> Binding<Bool> {
        Binding(
            get: { store.selectedScreenIdentifiers.contains(screen.id) },
            set: { select(screen, enabled: $0) }
        )
    }

    private func unavailableSelectionBinding(_ identifier: String) -> Binding<Bool> {
        Binding(
            get: { store.selectedScreenIdentifiers.contains(identifier) },
            set: { enabled in
                guard !enabled else { return }
                store.selectedScreenIdentifiers.removeAll { $0 == identifier }
                store.selectedScreenNames[identifier] = nil
            }
        )
    }

    private func select(_ screen: ScreenDescriptor, enabled: Bool) {
        if enabled {
            if !store.selectedScreenIdentifiers.contains(screen.id) {
                store.selectedScreenIdentifiers.append(screen.id)
            }
            store.selectedScreenNames[screen.id] = screen.name
        } else {
            store.selectedScreenIdentifiers.removeAll { $0 == screen.id }
            store.selectedScreenNames[screen.id] = nil
        }
    }

    private func screenDetail(_ screen: ScreenDescriptor) -> String {
        String(
            format: localized("settings.display.targetScreen.resolution"),
            screen.width,
            screen.height
        )
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, bundle: localizationBundle, comment: "")
    }

    private func refreshScreens() {
        screens = NSScreen.availableDescriptors
    }
}

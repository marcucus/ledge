import AppKit
import Core
import SwiftUI

struct DisplaySettingsView: View {
    var store: SettingsStore
    @State private var screens: [ScreenDescriptor] = []

    var body: some View {
        Form {
            Section {
                Picker(selection: targetScreenBinding) {
                    Text("settings.display.targetScreen.auto", bundle: localizationBundle)
                        .tag("")
                    ForEach(screens) { screen in
                        Text(menuLabel(for: screen)).tag(screen.id)
                    }
                    if isSelectedScreenUnavailable {
                        Text(unavailableMenuLabel).tag(store.targetScreenIdentifier)
                    }
                } label: {
                    Text("settings.display.targetScreen", bundle: localizationBundle)
                }

                selectedScreenSummary
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
        .navigationTitle(Text("settings.section.display", bundle: localizationBundle))
        .task { refreshScreens() }
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
        ) { _ in refreshScreens() }
    }

    private var targetScreenBinding: Binding<String> {
        Binding(
            get: { store.targetScreenIdentifier },
            set: { identifier in
                store.targetScreenIdentifier = identifier
                store.targetScreenName = screens.first(where: { $0.id == identifier })?.name ?? ""
            }
        )
    }

    @ViewBuilder
    private var selectedScreenSummary: some View {
        if store.targetScreenIdentifier.isEmpty {
            screenSummary(
                icon: "laptopcomputer",
                titleKey: "settings.display.targetScreen.auto.title",
                detail: automaticScreenDetail,
                statusKey: "settings.display.targetScreen.automatic"
            )
        } else if let screen = selectedScreen {
            screenSummary(
                icon: screen.isBuiltIn ? "laptopcomputer" : "display",
                title: screen.name,
                detail: screenDetail(screen),
                statusKey: screen.hasNotch
                    ? "settings.display.targetScreen.physicalNotch"
                    : "settings.display.targetScreen.simulatedNotch"
            )
        } else {
            screenSummary(
                icon: "display.trianglebadge.exclamationmark",
                title: unavailableScreenName,
                detailKey: "settings.display.targetScreen.unavailable.detail",
                statusKey: "settings.display.targetScreen.unavailable"
            )
        }
    }

    private func screenSummary(
        icon: String,
        title: String? = nil,
        titleKey: LocalizedStringKey? = nil,
        detail: String? = nil,
        detailKey: LocalizedStringKey? = nil,
        statusKey: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title).font(.body.weight(.medium))
                } else if let titleKey {
                    Text(titleKey, bundle: localizationBundle).font(.body.weight(.medium))
                }
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(.secondary)
                } else if let detailKey {
                    Text(detailKey, bundle: localizationBundle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(statusKey, bundle: localizationBundle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var selectedScreen: ScreenDescriptor? {
        screens.first { $0.id == store.targetScreenIdentifier }
    }

    private var isSelectedScreenUnavailable: Bool {
        !store.targetScreenIdentifier.isEmpty && selectedScreen == nil
    }

    private var unavailableScreenName: String {
        store.targetScreenName.isEmpty
            ? NSLocalizedString("settings.display.targetScreen.unknown", bundle: localizationBundle, comment: "")
            : store.targetScreenName
    }

    private var unavailableMenuLabel: String {
        String(
            format: NSLocalizedString(
                "settings.display.targetScreen.unavailable.format",
                bundle: localizationBundle,
                comment: ""
            ),
            unavailableScreenName
        )
    }

    private var automaticScreenDetail: String {
        let screen = screens.first(where: \.isBuiltIn) ?? screens.first
        return screen?.name ?? NSLocalizedString(
            "settings.display.targetScreen.unknown",
            bundle: localizationBundle,
            comment: ""
        )
    }

    private func menuLabel(for screen: ScreenDescriptor) -> String {
        let key = screen.isBuiltIn
            ? "settings.display.targetScreen.builtIn.format"
            : "settings.display.targetScreen.external.format"
        let baseLabel = String(
            format: NSLocalizedString(key, bundle: localizationBundle, comment: ""),
            screen.name
        )
        let matches = screens.filter { $0.name == screen.name && $0.isBuiltIn == screen.isBuiltIn }
        guard matches.count > 1, let index = matches.firstIndex(of: screen) else { return baseLabel }
        return String(
            format: NSLocalizedString(
                "settings.display.targetScreen.duplicate.format",
                bundle: localizationBundle,
                comment: ""
            ),
            baseLabel,
            index + 1
        )
    }

    private func screenDetail(_ screen: ScreenDescriptor) -> String {
        String(
            format: NSLocalizedString(
                "settings.display.targetScreen.resolution",
                bundle: localizationBundle,
                comment: ""
            ),
            screen.width,
            screen.height
        )
    }

    private func refreshScreens() {
        screens = NSScreen.availableDescriptors
        migrateLegacySelectionIfNeeded()
    }

    private func migrateLegacySelectionIfNeeded() {
        guard store.targetScreenIdentifier.isEmpty, !store.targetScreenName.isEmpty,
              let legacyScreen = screens.first(where: { $0.name == store.targetScreenName })
        else { return }
        store.targetScreenIdentifier = legacyScreen.id
    }
}

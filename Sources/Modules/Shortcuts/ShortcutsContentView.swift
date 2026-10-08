import Core
import SwiftUI

public struct ShortcutsContentView: View {
    public var module: ShortcutsModule

    @State private var searchQuery = ""

    public init(module: ShortcutsModule) {
        self.module = module
    }

    private var filteredShortcuts: [String] {
        guard !searchQuery.isEmpty else { return module.orderedShortcuts }
        return module.orderedShortcuts.filter { $0.localizedCaseInsensitiveContains(searchQuery) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.4)
            content
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text("module.shortcuts.label", bundle: localizationBundle)
                .font(.footnote.weight(.semibold))
            if !module.shortcuts.isEmpty {
                Text("\(module.shortcuts.count)")
                    .font(.caption2.monospacedDigit().weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            refreshButton
        }
        .padding(.horizontal, 14)
        .frame(height: 38)
    }

    private var refreshButton: some View {
        Button {
            Task { await module.refresh() }
        } label: {
            Group {
                if module.isLoading {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .disabled(module.isLoading)
        .help(Text("shortcuts.action.refresh", bundle: localizationBundle))
        .accessibilityLabel(Text("shortcuts.action.refresh", bundle: localizationBundle))
    }

    @ViewBuilder
    private var content: some View {
        if module.isLoading && module.shortcuts.isEmpty {
            loadingState
        } else if module.loadFailed && module.shortcuts.isEmpty {
            loadErrorState
        } else if module.shortcuts.isEmpty {
            emptyState
        } else {
            shortcutBrowser
        }
    }

    private var loadingState: some View {
        VStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text("shortcuts.loading", bundle: localizationBundle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadErrorState: some View {
        ModuleEmptyState(
            icon: "exclamationmark.triangle",
            titleKey: "shortcuts.error",
            detailKey: "shortcuts.error.detail",
            actionKey: "shortcuts.action.retry"
        ) {
            Task { await module.refresh() }
        }
    }

    private var emptyState: some View {
        ModuleEmptyState(
            icon: "square.stack.3d.up.slash",
            titleKey: "shortcuts.empty",
            detailKey: "shortcuts.empty.detail",
            actionKey: "shortcuts.action.refresh"
        ) {
            Task { await module.refresh() }
        }
    }

    private var shortcutBrowser: some View {
        VStack(spacing: 0) {
            searchField
            if let runningName = module.runningShortcutName {
                runProgressBanner(name: runningName)
            } else if let timedOutName = module.lastRunTimedOutName {
                runFailureBanner(name: timedOutName, timedOut: true)
            } else if let failedName = module.lastRunFailedName {
                runFailureBanner(name: failedName)
            }
            if filteredShortcuts.isEmpty {
                searchEmptyState
            } else {
                shortcutList
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            TextField(
                "",
                text: $searchQuery,
                prompt: Text("shortcuts.search.placeholder", bundle: localizationBundle)
            )
                .textFieldStyle(.plain)
                .font(.footnote)
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .accessibilityLabel(Text("shortcuts.action.clearSearch", bundle: localizationBundle))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9))
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .onExitCommand { searchQuery = "" }
    }

    private func runProgressBanner(name: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini)
            Text(name)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                module.cancelRun()
            } label: {
                Text("shortcuts.action.cancel", bundle: localizationBundle)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color.accentColor.opacity(0.08))
    }

    private func runFailureBanner(name: String, timedOut: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(runFailureMessage(name: name, timedOut: timedOut))
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button {
                module.run(name)
            } label: {
                Text("shortcuts.action.retry", bundle: localizationBundle)
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(Color.orange.opacity(0.08))
    }

    private func runFailureMessage(name: String, timedOut: Bool) -> String {
        String(
            format: NSLocalizedString(
                timedOut ? "shortcuts.run.timeout.format" : "shortcuts.run.error.format",
                bundle: localizationBundle,
                comment: ""
            ),
            name
        )
    }

    private var searchEmptyState: some View {
        ModuleEmptyState(
            icon: "magnifyingglass",
            titleKey: "shortcuts.search.empty",
            detailKey: "shortcuts.search.empty.detail",
            actionKey: "shortcuts.action.clearSearch"
        ) {
            searchQuery = ""
        }
    }

    private var shortcutList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredShortcuts.enumerated()), id: \.element) { index, name in
                    ShortcutRowView(name: name, module: module)
                    if index < filteredShortcuts.count - 1 {
                        Divider()
                            .opacity(0.28)
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

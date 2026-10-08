import Core
import Foundation
import SwiftUI

/// Module exposant les raccourcis de Shortcuts.app : liste et lancement via la CLI `/usr/bin/shortcuts`.
@MainActor
@Observable
public final class ShortcutsModule: NotchModule {
    public let id = "shortcuts"
    public let tabIcon = "bolt.fill"
    public let tabLabel: LocalizedStringKey = "module.shortcuts.label"

    public private(set) var shortcuts: [String] = []
    public private(set) var isLoading = false
    public private(set) var loadFailed = false
    public private(set) var runningShortcutName: String?
    public private(set) var lastRunFailedName: String?
    public private(set) var lastRunTimedOutName: String?
    public private(set) var lastRunSucceededName: String?
    public private(set) var favoriteShortcutNames: Set<String>
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var lifecycleGeneration = 0
    @ObservationIgnored private var successFeedbackTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var runTask: Task<Void, Never>?
    @ObservationIgnored private let commandRunner: any ShortcutsCommandRunning
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let listTimeout: Duration
    @ObservationIgnored private let runTimeout: Duration
    private static let favoriteShortcutNamesKey = "shortcutsFavoriteNames"

    public convenience init() {
        self.init(commandRunner: SystemShortcutsCommandRunner(), defaults: .standard)
    }

    init(
        commandRunner: any ShortcutsCommandRunning,
        defaults: UserDefaults = .standard,
        listTimeout: Duration = .seconds(5),
        runTimeout: Duration = .seconds(30)
    ) {
        self.commandRunner = commandRunner
        self.defaults = defaults
        self.listTimeout = listTimeout
        self.runTimeout = runTimeout
        favoriteShortcutNames = Set(
            defaults.stringArray(forKey: Self.favoriteShortcutNamesKey) ?? []
        )
    }

    // MARK: — NotchModule

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        refreshTask = Task { await refresh(generation: generation) }
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        lifecycleGeneration += 1
        refreshTask?.cancel()
        runTask?.cancel()
        successFeedbackTask?.cancel()
        isLoading = false
        runningShortcutName = nil
        lastRunSucceededName = nil
    }

    public func makePeekView() -> AnyView {
        AnyView(ShortcutsPeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(ShortcutsContentView(module: self))
    }

    // MARK: — Capture marketing

    /// Injecte une liste de raccourcis de démonstration sans passer par `/usr/bin/shortcuts` —
    /// utilisé uniquement par `MarketingCapture` (cf. docs/PLAN-REFONTE-FIDELITE.md).
    package func configureMarketingCapture(
        shortcuts: [String],
        favorites: Set<String> = []
    ) {
        self.shortcuts = shortcuts
        favoriteShortcutNames = favorites
        isLoading = false
        loadFailed = false
    }

    // MARK: — Public API

    /// Recharge la liste des raccourcis disponibles depuis `shortcuts list`.
    public func refresh() async {
        await refresh(generation: lifecycleGeneration)
    }

    private func refresh(generation: Int) async {
        guard isStarted, lifecycleGeneration == generation else { return }
        isLoading = true
        let result = await listShortcuts()
        guard isStarted, lifecycleGeneration == generation else { return }
        switch result {
        case let .success(names):
            shortcuts = names
            loadFailed = false
        case .failure:
            loadFailed = true
        }
        isLoading = false
    }

    /// Lance un raccourci par son nom, en tâche de fond (fire-and-forget).
    public func run(_ name: String) {
        guard isStarted, runningShortcutName == nil else { return }
        successFeedbackTask?.cancel()
        runningShortcutName = name
        lastRunFailedName = nil
        lastRunTimedOutName = nil
        lastRunSucceededName = nil
        let generation = lifecycleGeneration
        runTask = Task {
            let result = await runShortcut(named: name)
            guard isStarted, lifecycleGeneration == generation else { return }
            runningShortcutName = nil
            switch result {
            case .success:
                showSuccessFeedback(for: name, generation: generation)
            case .failed:
                lastRunFailedName = name
            case .timedOut:
                lastRunTimedOutName = name
            case .cancelled:
                break
            }
        }
    }

    public func cancelRun() {
        runTask?.cancel()
        runTask = nil
        runningShortcutName = nil
    }

    public func isFavorite(_ name: String) -> Bool {
        favoriteShortcutNames.contains(name)
    }

    public func toggleFavorite(_ name: String) {
        if favoriteShortcutNames.contains(name) {
            favoriteShortcutNames.remove(name)
        } else {
            favoriteShortcutNames.insert(name)
        }
        defaults.set(favoriteShortcutNames.sorted(), forKey: Self.favoriteShortcutNamesKey)
    }

    public var orderedShortcuts: [String] {
        let favorites = shortcuts.filter(favoriteShortcutNames.contains)
        let others = shortcuts.filter { !favoriteShortcutNames.contains($0) }
        return favorites + others
    }

    private func showSuccessFeedback(for name: String, generation: Int) {
        lastRunSucceededName = name
        successFeedbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled,
                  let self,
                  self.isStarted,
                  self.lifecycleGeneration == generation else { return }
            self.lastRunSucceededName = nil
        }
    }

    // MARK: — Process helpers

    private func listShortcuts() async -> Result<[String], ProcessFailure> {
        let result = await commandRunner.output(arguments: ["list"], timeout: listTimeout)
        guard case let .success(output) = result else { return .failure(.commandFailed) }
        let names = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return .success(names)
    }

    private func runShortcut(named name: String) async -> ShortcutsCommandResult {
        await commandRunner.output(arguments: ["run", name], timeout: runTimeout)
    }

    private enum ProcessFailure: Error {
        case commandFailed
    }
}

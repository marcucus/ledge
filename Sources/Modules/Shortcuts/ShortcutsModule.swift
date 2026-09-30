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
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var lifecycleGeneration = 0
    @ObservationIgnored private let commandRunner: any ShortcutsCommandRunning

    public convenience init() {
        self.init(commandRunner: SystemShortcutsCommandRunner())
    }

    init(commandRunner: any ShortcutsCommandRunning) {
        self.commandRunner = commandRunner
    }

    // MARK: — NotchModule

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        Task { await refresh(generation: generation) }
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        lifecycleGeneration += 1
        isLoading = false
        runningShortcutName = nil
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
    package func configureMarketingCapture(shortcuts: [String]) {
        self.shortcuts = shortcuts
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
        runningShortcutName = name
        lastRunFailedName = nil
        let generation = lifecycleGeneration
        Task {
            let succeeded = await runShortcut(named: name)
            guard isStarted, lifecycleGeneration == generation else { return }
            runningShortcutName = nil
            if !succeeded { lastRunFailedName = name }
        }
    }

    // MARK: — Process helpers

    private func listShortcuts() async -> Result<[String], ProcessFailure> {
        let output = await commandRunner.output(arguments: ["list"])
        guard let output else { return .failure(.commandFailed) }
        let names = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return .success(names)
    }

    private func runShortcut(named name: String) async -> Bool {
        await commandRunner.output(arguments: ["run", name]) != nil
    }

    private enum ProcessFailure: Error {
        case commandFailed
    }
}

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

    public init() {}

    // MARK: — NotchModule

    public func start() {
        Task { await refresh() }
    }

    public func stop() {}

    public func makePeekView() -> AnyView {
        AnyView(ShortcutsPeekView(module: self))
    }

    public func makeContentView() -> AnyView {
        AnyView(ShortcutsContentView(module: self))
    }

    // MARK: — Public API

    /// Recharge la liste des raccourcis disponibles depuis `shortcuts list`.
    public func refresh() async {
        isLoading = true
        shortcuts = await Self.listShortcuts()
        isLoading = false
    }

    /// Lance un raccourci par son nom, en tâche de fond (fire-and-forget).
    public func run(_ name: String) {
        Task.detached {
            await Self.runShortcut(named: name)
        }
    }

    // MARK: — Process helpers

    private nonisolated static func listShortcuts() async -> [String] {
        let output = await runProcess(arguments: ["list"])
        guard let output else { return [] }
        return output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private nonisolated static func runShortcut(named name: String) async {
        _ = await runProcess(arguments: ["run", name])
    }

    /// Exécute `/usr/bin/shortcuts <arguments>` hors du thread principal et renvoie sa sortie standard,
    /// ou `nil` si l'outil est absent ou la commande échoue.
    private nonisolated static func runProcess(arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            // File dédiée : on draine le pipe AVANT `waitUntilExit`. Lire dans le
            // `terminationHandler` (après la fin) bloquerait le process si sa sortie dépasse le
            // buffer du pipe (~64 Ko) → terminaison jamais atteinte, continuation jamais reprise.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                process.arguments = arguments
                let output = Pipe()
                process.standardOutput = output
                process.standardError = Pipe()
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: String(data: data, encoding: .utf8))
            }
        }
    }
}

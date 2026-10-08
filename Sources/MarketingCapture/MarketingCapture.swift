import AppKit
import CalendarModule
import ClipboardModule
import Core
import DropZoneModule
import EventKit
import Foundation
import MediaModule
import NotesModule
import ShortcutsModule
import SwiftUI
import TimerModule

@main
struct MarketingCapture {
    @MainActor
    static func main() throws {
        let arguments = CaptureArguments.parse(CommandLine.arguments)
        try FileManager.default.createDirectory(
            at: arguments.outputDirectory,
            withIntermediateDirectories: true
        )
        let artwork = NSImage(contentsOf: arguments.artworkURL)
        let mediaState = makeMediaState(artwork: artwork)
        let requests = captureRequests(mediaState: mediaState, artwork: artwork)
        let assets = try requests.map {
            try render($0, mediaState: mediaState, outputDirectory: arguments.outputDirectory)
        }
        try writeManifest(
            assets: assets,
            version: arguments.version,
            outputDirectory: arguments.outputDirectory
        )
        print("Captures Ledge écrites dans \(arguments.outputDirectory.path)")
    }

    private static func makeMediaState(artwork: NSImage?) -> MediaState {
        MediaState(
            title: "Ledge Demo", artist: "Ledge", album: "Product Preview",
            artwork: artwork, isPlaying: true, elapsed: 72, duration: 214,
            shuffleMode: 0, repeatMode: 0
        )
    }

    private static func captureRequests(mediaState: MediaState, artwork: NSImage?) -> [CaptureRequest] {
        let accent = Color(red: 0.48, green: 0.36, blue: 0.96)
        let ambient = AmbientContent(
            kind: .music(
                artwork: artwork, isPlaying: true,
                elapsed: mediaState.elapsed, duration: mediaState.duration
            ),
            accentColor: accent
        )
        let ambientRequest = CaptureRequest(
            name: "ambient", kind: .media, composition: .panoramic, state: .ambient, ambient: ambient
        )
        let compositionRequests = PanelComposition.allCases.map {
            CaptureRequest(name: "media-\($0.captureName)", kind: .media, composition: $0, state: .expanded)
        }
        // Une capture « focused » par module restant — pensée pour une future grille dans la
        // section Modules du site (cf. docs/PLAN-REFONTE-FIDELITE.md, dernière étape). Ces
        // captures n'ont jamais été générées ni vérifiées visuellement : la composition
        // `.focused` est un choix par défaut, à ajuster si le rendu réel ne convient pas.
        let otherModuleRequests: [CaptureRequest] = [
            CaptureRequest(name: "timers-focused", kind: .timers, composition: .focused, state: .expanded),
            CaptureRequest(name: "dropzone-focused", kind: .dropzone, composition: .focused, state: .expanded),
            CaptureRequest(name: "clipboard-focused", kind: .clipboard, composition: .focused, state: .expanded),
            CaptureRequest(name: "shortcuts-focused", kind: .shortcuts, composition: .focused, state: .expanded),
            CaptureRequest(name: "calendar-focused", kind: .calendar, composition: .focused, state: .expanded),
            CaptureRequest(name: "notes-focused", kind: .notes, composition: .focused, state: .expanded),
        ]
        return [ambientRequest] + compositionRequests + otherModuleRequests
    }

    private static func writeManifest(
        assets: [CaptureAsset],
        version: String,
        outputDirectory: URL
    ) throws {
        let manifest = CaptureManifest(
            version: version,
            scale: 2,
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            assets: assets
        )
        let data = try JSONEncoder.pretty.encode(manifest)
        try data.write(to: outputDirectory.appendingPathComponent("manifest.json"))
    }

    @MainActor
    // La fonction garde volontairement la création du contexte et son rendu dans la même portée
    // afin de nettoyer les ressources temporaires (UserDefaults, fichiers de démonstration) avec
    // `defer`.
    // swiftlint:disable:next function_body_length
    private static func render(
        _ request: CaptureRequest,
        mediaState: MediaState,
        outputDirectory: URL
    ) throws -> CaptureAsset {
        let defaultsName = "me.adrienmarques.ledge.marketing.\(request.name).\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsName) else {
            throw CaptureError.defaultsUnavailable
        }
        defer { defaults.removePersistentDomain(forName: defaultsName) }

        let settings = SettingsStore(defaults: defaults)
        settings.panelComposition = request.composition
        settings.panelOpacity = 1
        settings.cornerRadius = 12

        let (module, temporaryDirectory) = try makeModule(for: request, mediaState: mediaState, defaults: defaults)
        defer {
            if let temporaryDirectory {
                try? FileManager.default.removeItem(at: temporaryDirectory)
            }
        }

        let controller = NotchController(settings: settings)
        controller.notchWidth = 190
        controller.notchHeight = 32
        controller.configureMarketingCapture(
            modules: [module],
            selectedModuleID: module.id,
            state: request.state,
            ambientContent: request.ambient
        )

        let size = captureSize(for: controller, state: request.state)
        let view = MarketingCaptureView(controller: controller)
            .frame(width: size.width, height: size.height, alignment: .top)
            .environment(\.locale, Locale(identifier: "fr"))
        let png = try MarketingCaptureRenderer.renderPNG(view: view, size: size, name: request.name)

        let filename = "\(request.name)@2x.png"
        try png.write(to: outputDirectory.appendingPathComponent(filename))
        return CaptureAsset(
            id: request.name,
            file: filename,
            width: Int(size.width),
            height: Int(size.height),
            state: request.state.captureName,
            composition: request.composition.captureName
        )
    }

    @MainActor
    private static func captureSize(for controller: NotchController, state: NotchState) -> CGSize {
        switch state {
        case .ambient:
            CGSize(
                width: controller.notchWidth + 2 * (
                    NotchController.ambientPillWidth + NotchController.ambientPillGap
                ),
                height: controller.notchHeight
            )
        case .expanded:
            CGSize(
                width: controller.expandedWidth,
                height: controller.navigationHeight + controller.expandedContentHeight
            )
        case .collapsed:
            CGSize(width: controller.notchWidth, height: controller.notchHeight)
        case .peeking, .hud:
            CGSize(width: controller.expandedWidth, height: controller.navigationHeight)
        }
    }

    // MARK: — Construction des modules de démonstration

    /// Construit une instance fraîche du module ciblé par `request`, peuplée de données de
    /// démonstration stables via `configureMarketingCapture` (jamais `start()`, pour éviter tout
    /// observateur système réel). Retourne aussi un répertoire temporaire à nettoyer après le
    /// rendu, quand le module en a créé un (Drop Zone).
    ///
    /// AUCUNE de ces méthodes n'a été compilée ni exécutée par l'agent qui les a écrites (pas de
    /// toolchain Swift disponible) — à vérifier avec
    /// `swift build --product MarketingCapture && npm run capture:product`.
    @MainActor
    private static func makeModule(
        for request: CaptureRequest,
        mediaState: MediaState,
        defaults: UserDefaults
    ) throws -> (module: any NotchModule, temporaryDirectory: URL?) {
        switch request.kind {
        case .media:
            let media = MediaModule()
            media.configureMarketingCapture(
                state: mediaState, accentColor: .init(red: 0.48, green: 0.36, blue: 0.96)
            )
            return (media, nil)
        case .timers:
            return (makeTimerModule(), nil)
        case .dropzone:
            let (module, directory) = try makeDropZoneModule()
            return (module, directory)
        case .clipboard:
            return (makeClipboardModule(), nil)
        case .shortcuts:
            return (makeShortcutsModule(), nil)
        case .calendar:
            return (makeCalendarModule(), nil)
        case .notes:
            return (makeNotesModule(defaults: defaults), nil)
        }
    }

    @MainActor
    private static func makeTimerModule() -> TimerModule {
        let module = TimerModule()
        var running = TimerEntry(label: "Pause café", duration: 5 * 60)
        running.isRunning = true
        running.remaining = 2 * 60 + 12
        var paused = TimerEntry(label: "Sprint focus", duration: 25 * 60)
        paused.isPaused = true
        paused.remaining = 14 * 60 + 30
        let idle = TimerEntry(label: "Étirements", duration: 10 * 60)
        module.configureMarketingCapture(entries: [running, paused, idle])
        return module
    }

    /// Crée trois fichiers factices sur disque (nécessaire : `ShelfItem.isAvailable` vérifie
    /// l'existence réelle du fichier) dans un répertoire temporaire dédié, que l'appelant doit
    /// supprimer une fois le rendu terminé.
    @MainActor
    private static func makeDropZoneModule() throws -> (DropZoneModule, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ledge-marketing-dropzone-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filenames = ["Roadmap-Q3.pdf", "Capture-écran.png", "Notes-réunion.docx"]
        let demoContent = Data("Ledge — fichier de démonstration".utf8)
        for name in filenames {
            try demoContent.write(to: directory.appendingPathComponent(name))
        }
        let module = DropZoneModule()
        module.configureMarketingCapture(
            items: filenames.map { ShelfItem(url: directory.appendingPathComponent($0)) }
        )
        return (module, directory)
    }

    @MainActor
    private static func makeClipboardModule() -> ClipboardModule {
        let module = ClipboardModule()
        let now = Date()
        guard let changelogURL = URL(string: "https://app-ledge.fr/changelog") else {
            module.configureMarketingCapture(items: [])
            return module
        }
        let items = [
            ClipboardItem(content: .text("Merci pour la relecture, je pousse la branche ce soir."), date: now),
            ClipboardItem(content: .url(changelogURL), date: now.addingTimeInterval(-620), isPinned: true),
            ClipboardItem(content: .text("PROD-2461"), date: now.addingTimeInterval(-3100)),
        ]
        module.configureMarketingCapture(items: items)
        return module
    }

    @MainActor
    private static func makeShortcutsModule() -> ShortcutsModule {
        let module = ShortcutsModule()
        module.configureMarketingCapture(
            shortcuts: [
                "Résumer le presse-papiers",
                "Basculer le Wi-Fi",
                "Créer une note rapide",
                "Exporter en PDF",
            ],
            favorites: ["Basculer le Wi-Fi"]
        )
        return module
    }

    @MainActor
    private static func makeCalendarModule() -> CalendarModule {
        let module = CalendarModule()
        let event = EKEvent(eventStore: EKEventStore())
        event.title = "Point produit"
        event.startDate = Date().addingTimeInterval(45 * 60)
        event.endDate = event.startDate.addingTimeInterval(30 * 60)
        module.configureMarketingCapture(event: event)
        return module
    }

    @MainActor
    private static func makeNotesModule(defaults: UserDefaults) -> NotesModule {
        let module = NotesModule(defaults: defaults)
        module.text = "Idée : ajouter un raccourci clavier pour épingler un élément du presse-papiers."
        return module
    }
}

private struct CaptureArguments {
    let outputDirectory: URL
    let artworkURL: URL
    let version: String

    static func parse(_ arguments: [String]) -> CaptureArguments {
        let outputPath = value(after: "--output", in: arguments) ?? "MarketingCaptures"
        let artworkPath = value(after: "--artwork", in: arguments) ?? "ledgelogo.png"
        let version = value(after: "--version", in: arguments) ?? "development"
        return CaptureArguments(
            outputDirectory: URL(fileURLWithPath: outputPath, isDirectory: true),
            artworkURL: URL(fileURLWithPath: artworkPath),
            version: version
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

/// Quel module `render()` doit instancier pour une requête donnée. `.media` reste le seul cas
/// utilisé pour l'ambient pill et les 3 compositions ; les 6 autres cas produisent chacun une
/// unique capture « focused » (cf. `captureRequests`).
private enum CaptureModuleKind {
    case media
    case timers
    case dropzone
    case clipboard
    case shortcuts
    case calendar
    case notes
}

private struct CaptureRequest {
    let name: String
    let kind: CaptureModuleKind
    let composition: PanelComposition
    let state: NotchState
    var ambient: AmbientContent?

    init(
        name: String,
        kind: CaptureModuleKind = .media,
        composition: PanelComposition,
        state: NotchState,
        ambient: AmbientContent? = nil
    ) {
        self.name = name
        self.kind = kind
        self.composition = composition
        self.state = state
        self.ambient = ambient
    }
}

private struct CaptureManifest: Encodable {
    let version: String
    let scale: Int
    let generatedAt: String
    let assets: [CaptureAsset]
}

private struct CaptureAsset: Encodable {
    let id: String
    let file: String
    let width: Int
    let height: Int
    let state: String
    let composition: String
}

enum CaptureError: Error {
    case defaultsUnavailable
    case renderFailed(String)
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension PanelComposition {
    var captureName: String {
        switch self {
        case .focused: "focused"
        case .panoramic: "panoramic"
        case .immersive: "immersive"
        }
    }
}

private extension NotchState {
    var captureName: String {
        switch self {
        case .collapsed: "collapsed"
        case .ambient: "ambient"
        case .peeking: "peeking"
        case .hud: "hud"
        case .expanded: "expanded"
        }
    }
}

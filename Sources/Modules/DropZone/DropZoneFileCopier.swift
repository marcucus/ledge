import Foundation

struct DropZoneCopyRequest: Sendable {
    let sourceURL: URL
    let displayName: String
}

protocol DropZoneCopying: Sendable {
    func copy(_ request: DropZoneCopyRequest, to directory: URL) async -> Bool
}

/// Effectue les entrées/sorties de la Drop Zone hors du `MainActor`.
///
/// `FileManager.copyItem` n'est pas interruptible pendant la copie d'un fichier. Une annulation
/// prend donc effet entre deux éléments, après la fin de l'opération déjà engagée.
struct DropZoneFileCopier: DropZoneCopying {
    func copy(_ request: DropZoneCopyRequest, to directory: URL) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let destination = uniqueDestination(
                for: request.displayName,
                in: directory,
                fileManager: fileManager
            )
            do {
                try fileManager.copyItem(at: request.sourceURL, to: destination)
                return true
            } catch {
                return false
            }
        }.value
    }

    /// Ajoute un suffixe numéroté à la façon du Finder lorsque le nom existe déjà.
    func uniqueDestination(
        for displayName: String,
        in destination: URL,
        fileManager: FileManager
    ) -> URL {
        var candidate = destination.appendingPathComponent(displayName)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let baseName = (displayName as NSString).deletingPathExtension
        let fileExtension = (displayName as NSString).pathExtension
        var suffix = 2
        repeat {
            let newName = fileExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(fileExtension)"
            candidate = destination.appendingPathComponent(newName)
            suffix += 1
        } while fileManager.fileExists(atPath: candidate.path)
        return candidate
    }
}

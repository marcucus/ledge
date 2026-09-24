import Foundation

/// Retourne le bundle localisé selon la langue choisie dans les préférences.
/// Computed var : se réévalue à chaque appel, donc réactif au changement via UserDefaults.
public var localizationBundle: Bundle {
    let lang = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "system"
    guard lang != "system",
          let path = _ledgeCoreBundle.path(forResource: lang, ofType: "lproj"),
          let bundle = Bundle(path: path)
    else { return _ledgeCoreBundle }
    return bundle
}

/// Ledge_Core.bundle trouvé sans dépendre de Bundle.module (qui peut être remplacé
/// par la version du target App lorsque les deux modules sont liés dans le même binaire).
private let _ledgeCoreBundle: Bundle = {
    // 1. Swift run / binaire non-bundle : Ledge_Core.bundle est dans le même répertoire que l'exécutable
    if let execURL = Bundle.main.executableURL {
        let candidate = execURL.deletingLastPathComponent().appendingPathComponent("Ledge_Core.bundle")
        if let b = Bundle(url: candidate) { return b }
    }
    // 2. .app bundle : les bundles SPM sont dans Contents/Resources/
    if let resURL = Bundle.main.resourceURL {
        let candidate = resURL.appendingPathComponent("Ledge_Core.bundle")
        if let b = Bundle(url: candidate) { return b }
    }
    // 3. Fallback
    return .module
}()

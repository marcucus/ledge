import Foundation

/// Retourne le bundle localisé selon la langue choisie dans les préférences.
/// Computed var : se réévalue à chaque appel, donc réactif au changement via UserDefaults.
public var localizationBundle: Bundle {
    let lang = UserDefaults.standard.string(forKey: "preferredLanguage") ?? "system"
    guard lang != "system",
          let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
          let bundle = Bundle(path: path)
    else { return .module }
    return bundle
}

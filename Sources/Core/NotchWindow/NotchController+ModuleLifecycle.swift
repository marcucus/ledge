import Foundation

// MARK: — Cycle de vie des modules (doc 13, Jalon 2)

/// Relie le cycle de vie réel des modules (`start()`/`stop()`) à leur activation, qu'elle vienne
/// des réglages globaux (`SettingsStore.isModuleEnabled`) ou du profil d'app actif
/// (`AppProfile.disabledModuleIDs`). Voir `NotchModule` pour la définition précise de
/// visible/enabled/captureEnabled.
extension NotchController {
    /// Démarre les modules dont l'activation vient d'être obtenue et arrête ceux qui viennent de
    /// la perdre. Seule source de vérité du cycle de vie : un module masqué par les réglages ou
    /// par un profil d'app est réellement arrêté (`stop()`), pas seulement caché de la navigation
    /// (`visibleModules` reste purement UI). C'est ce qui garantit, par exemple, qu'un
    /// presse-papiers désactivé ne capture plus rien.
    func applyModuleActivation() {
        let (_, isEnabled) = moduleVisibilityRules()
        for module in modules {
            let shouldRun = isEnabled(module)
            let isRunning = startedModuleIDs.contains(module.id)
            guard shouldRun != isRunning else { continue }
            if shouldRun {
                module.start()
                startedModuleIDs.insert(module.id)
            } else {
                moduleDidStop(id: module.id)
                module.stop()
                startedModuleIDs.remove(module.id)
            }
        }
    }

    /// Applique l'activation courante puis se réarme sur tout changement pertinent de
    /// `SettingsStore` (modules désactivés, profils d'app). `updateActiveProfile` appelle
    /// `applyModuleActivation()` directement pour le changement d'app au premier plan, qui ne
    /// passe pas par une propriété observable de `SettingsStore`.
    func refreshModuleActivation() {
        withObservationTracking {
            applyModuleActivation()
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                self?.refreshModuleActivation()
            }
        }
    }
}

import Foundation

// MARK: — Réinitialisation des réglages (doc 13, Jalon 4, item 27)

extension SettingsStore {
    /// Réinitialise tous les réglages persistés à leurs valeurs par défaut. Supprime chaque clé
    /// `UserDefaults`, puis relit les valeurs par défaut via une instance jetable de
    /// `SettingsStore` construite sur les mêmes `UserDefaults` (désormais vides) : cela réutilise
    /// exactement la logique de valeurs par défaut de `init(defaults:)` au lieu de la dupliquer
    /// ici, où deux listes d'une cinquantaine de valeurs pourraient diverger avec le temps.
    /// Les propriétés `@Observable` étant réassignées directement, l'effet est immédiat — pas
    /// besoin de relancer l'app (contrairement au changement de langue, qui modifie
    /// `AppleLanguages`).
    public func resetToDefaults() {
        for key in Keys.all {
            defaults.removeObject(forKey: key)
        }
        let fresh = SettingsStore(defaults: defaults)
        applyGeneralResetValues(from: fresh)
        applyModuleResetValues(from: fresh)
    }

    private func applyGeneralResetValues(from fresh: SettingsStore) {
        hasCompletedOnboarding = fresh.hasCompletedOnboarding
        collapseDelay = fresh.collapseDelay
        hotZoneSize = fresh.hotZoneSize
        moduleOrder = fresh.moduleOrder
        disabledModuleIDs = fresh.disabledModuleIDs
        hudReplaceSystem = fresh.hudReplaceSystem
        hudBrightnessManualOnly = fresh.hudBrightnessManualOnly
        hudUseSystemAccent = fresh.hudUseSystemAccent
        hudAccentColorComponents = fresh.hudAccentColorComponents
        panelComposition = fresh.panelComposition
        focusedModulePlacements = fresh.focusedModulePlacements
        panoramicModulePlacements = fresh.panoramicModulePlacements
        immersiveModulePlacements = fresh.immersiveModulePlacements
        focusedShowsModuleGrid = fresh.focusedShowsModuleGrid
        panoramicShowsModuleGrid = fresh.panoramicShowsModuleGrid
        immersiveShowsModuleGrid = fresh.immersiveShowsModuleGrid
        compositionModuleOrders = fresh.compositionModuleOrders
        cornerRadius = fresh.cornerRadius
        panelOpacity = fresh.panelOpacity
        notchDetectionMode = fresh.notchDetectionMode
        fullscreenBehavior = fresh.fullscreenBehavior
        showRingWhenTimerActive = fresh.showRingWhenTimerActive
        animationSpeed = fresh.animationSpeed
        clickBehavior = fresh.clickBehavior
    }

    private func applyModuleResetValues(from fresh: SettingsStore) {
        globalShortcutEnabled = fresh.globalShortcutEnabled
        shortcutOpenClose = fresh.shortcutOpenClose
        shortcutPaste = fresh.shortcutPaste
        shortcutNewTimer = fresh.shortcutNewTimer
        shortcutOpenMedia = fresh.shortcutOpenMedia
        clipboardMaxItems = fresh.clipboardMaxItems
        clipboardPersistEnabled = fresh.clipboardPersistEnabled
        clipboardExcludedApps = fresh.clipboardExcludedApps
        timerSoundEnabled = fresh.timerSoundEnabled
        timerAlertVisualOnly = fresh.timerAlertVisualOnly
        timerFinishedPeekEnabled = fresh.timerFinishedPeekEnabled
        timerFinishedPeekDuration = fresh.timerFinishedPeekDuration
        pomodoroWorkDuration = fresh.pomodoroWorkDuration
        pomodoroShortBreakDuration = fresh.pomodoroShortBreakDuration
        pomodoroLongBreakDuration = fresh.pomodoroLongBreakDuration
        targetScreenIdentifier = fresh.targetScreenIdentifier
        targetScreenName = fresh.targetScreenName
        ambientShowArtwork = fresh.ambientShowArtwork
        ambientShowProgress = fresh.ambientShowProgress
        dropZoneAcceptFolders = fresh.dropZoneAcceptFolders
        appProfiles = fresh.appProfiles
    }
}

extension Keys {
    /// Toutes les clés persistées par `SettingsStore`, utilisées uniquement par
    /// `resetToDefaults()`. Inclut `legacyPanelWidth` (clé de migration héritée) pour qu'une
    /// réinitialisation complète ne laisse aucun résidu.
    static var all: [String] {
        [
            hasCompletedOnboarding, collapseDelay, hotZoneSize, moduleOrder, disabledModules,
            hudReplaceSystem, hudBrightnessManualOnly, hudUseSystemAccent, hudAccentColorComponents,
            panelComposition, focusedModulePlacements, panoramicModulePlacements,
            immersiveModulePlacements, focusedShowsModuleGrid, panoramicShowsModuleGrid,
            immersiveShowsModuleGrid, compositionModuleOrders, legacyPanelWidth, cornerRadius,
            panelOpacity, notchDetectionMode, fullscreenBehavior, showRingWhenTimerActive,
            animationSpeed, clickBehavior, timerSoundEnabled, timerAlertVisualOnly,
            timerFinishedPeekEnabled, timerFinishedPeekDuration, globalShortcutEnabled,
            shortcutOpenClose, shortcutPaste, shortcutNewTimer, shortcutOpenMedia,
            clipboardMaxItems, clipboardPersistEnabled, clipboardExcludedApps,
            pomodoroWorkDuration, pomodoroShortBreakDuration, pomodoroLongBreakDuration,
            targetScreenIdentifier, targetScreenName, ambientShowArtwork, ambientShowProgress,
            dropZoneAcceptFolders, appProfiles, legacyLauncherApps, legacySystemShowCPU,
            legacySystemShowRAM, legacySystemShowBattery, legacySystemShowNetwork,
            legacySystemShowMicrophoneIndicator, legacySystemShowAccessoryBattery,
        ]
    }
}

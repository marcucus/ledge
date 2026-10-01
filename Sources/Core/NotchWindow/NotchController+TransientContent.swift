import Foundation

public extension NotchController {
    /// Enregistre ou retire un contributeur ambient. La source avec la priorité la plus haute gagne.
    func setAmbient(_ content: AmbientContent?, sourceID: String, priority: Int) {
        let wasRingActive = timerRingActive

        if let content {
            ambientSources[sourceID] = (priority: priority, content: content)
        } else {
            ambientSources.removeValue(forKey: sourceID)
        }
        let best = ambientSources.values.max(by: { $0.priority < $1.priority })
        ambientContent = best?.content

        let bestIsTimerInRingMode = ambientContent.map { content in
            if case .timer = content.kind { return settings.showRingWhenTimerActive }
            return false
        } ?? false

        if ambientContent != nil && !bestIsTimerInRingMode && !suppressesTransientContentInFullscreen {
            if state == .collapsed { transition(to: .ambient) }
        } else if state == .ambient {
            transition(to: .collapsed)
        }

        if state == .collapsed && timerRingActive != wasRingActive {
            onTransition?(state)
        }
    }

    func showHUD(_ content: HUDContent) {
        hudTask?.cancel()
        guard state != .expanded, !suppressesTransientContentInFullscreen else { return }
        hudContent = content
        if state == .collapsed || state == .hud || state == .ambient {
            transition(to: .hud)
        }
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1600))
            guard let self, !Task.isCancelled else { return }
            hudContent = nil
            if state == .hud { transition(to: fallbackState) }
        }
    }

    /// Affiche brièvement le peek d'un module désigné puis revient à l'état précédent.
    func showPeek(selecting moduleID: String, duration: TimeInterval) {
        guard state != .expanded, !suppressesTransientContentInFullscreen else { return }
        guard contentModules.contains(where: { $0.id == moduleID }) else { return }
        collapseTask?.cancel()
        hudTask?.cancel()
        selectModule(id: moduleID)
        if state == .collapsed || state == .hud || state == .ambient {
            transition(to: .peeking)
        }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard let self, !Task.isCancelled else { return }
            if state == .peeking { transition(to: fallbackState) }
        }
    }
}

import Foundation

@Observable final class NotchController {
    private(set) var state: NotchState = .collapsed

    /// Appelé à chaque transition — NotchWindow l'utilise pour se redimensionner.
    var onTransition: ((NotchState) -> Void)?

    private var collapseTask: Task<Void, Never>?

    func cursorEntered() {
        guard state == .collapsed else { return }
        collapseTask?.cancel()
        transition(to: .peeking)
    }

    func cursorExited() {
        guard state == .peeking else { return }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timing.collapseDelay))
            guard let self, !Task.isCancelled, state == .peeking else { return }
            transition(to: .collapsed)
        }
    }

    func panelClicked() {
        collapseTask?.cancel()
        transition(to: state == .expanded ? .collapsed : .expanded)
    }

    func dismiss() {
        collapseTask?.cancel()
        transition(to: .collapsed)
    }

    private func transition(to newState: NotchState) {
        guard newState != state else { return }
        state = newState
        onTransition?(newState)
    }
}

private enum Timing {
    static let collapseDelay: TimeInterval = 0.6
}

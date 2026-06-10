import Foundation

@Observable final class NotchController {
    private(set) var state: NotchState = .collapsed
    private(set) var modules: [any NotchModule] = []
    private(set) var selectedModuleID: String = ""

    var onTransition: ((NotchState) -> Void)?
    private var collapseTask: Task<Void, Never>?

    var selectedModule: (any NotchModule)? {
        modules.first { $0.id == selectedModuleID } ?? modules.first
    }

    func register(modules: [any NotchModule]) {
        self.modules = modules
        selectedModuleID = modules.first?.id ?? ""
        modules.forEach { $0.start() }
    }

    func selectModule(id: String) {
        guard modules.contains(where: { $0.id == id }) else { return }
        selectedModuleID = id
    }

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

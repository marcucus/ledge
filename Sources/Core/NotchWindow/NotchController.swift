import Foundation

@MainActor @Observable public final class NotchController {
    public private(set) var state: NotchState = .collapsed
    public private(set) var modules: [any NotchModule] = []
    public private(set) var selectedModuleID: String = ""
    public var notchWidth: CGFloat = 190
    public var notchHeight: CGFloat = 32

    public var onTransition: ((NotchState) -> Void)?
    public var openSettings: (() -> Void)?
    private var collapseTask: Task<Void, Never>?

    public var selectedModule: (any NotchModule)? {
        modules.first { $0.id == selectedModuleID } ?? modules.first
    }

    public init() {}

    public func register(modules: [any NotchModule]) {
        self.modules = modules
        selectedModuleID = modules.first?.id ?? ""
        modules.forEach { $0.start() }
    }

    public func selectModule(id: String) {
        guard modules.contains(where: { $0.id == id }) else { return }
        selectedModuleID = id
    }

    public func cursorEntered() {
        collapseTask?.cancel()
        guard state == .collapsed else { return }
        transition(to: .expanded)
    }

    public func cursorExited() {
        guard state == .expanded else { return }
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Timing.collapseDelay))
            guard let self, !Task.isCancelled, self.state == .expanded else { return }
            self.transition(to: .collapsed)
        }
    }

    public func panelClicked() {
        collapseTask?.cancel()
        transition(to: state == .expanded ? .collapsed : .expanded)
    }

    public func dismiss() {
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

import AppKit

/// Observe uniquement les drags système et signale l'entrée/sortie de la zone proche de l'encoche.
@MainActor
final class NotchFileDragMonitor {
    nonisolated(unsafe) private var dragMonitor: Any?
    nonisolated(unsafe) private var mouseUpMonitor: Any?
    private var isInsideZone = false

    func start(
        zone: @escaping @MainActor () -> CGRect?,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        guard dragMonitor == nil else { return }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            Task { @MainActor [weak self] in self?.handleDrag(zone: zone, onChange: onChange) }
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            Task { @MainActor [weak self] in self?.finish(onChange: onChange) }
        }
    }

    private func handleDrag(
        zone: @escaping @MainActor () -> CGRect?,
        onChange: @escaping @MainActor (Bool) -> Void
    ) {
        let types = NSPasteboard(name: .drag).types ?? []
        let hasFiles = types.contains {
            $0.rawValue == "public.file-url" || $0.rawValue == "NSFilenamesPboardType"
        }
        let shouldBeInside = hasFiles && (zone()?.contains(NSEvent.mouseLocation) == true)
        guard shouldBeInside != isInsideZone else { return }
        isInsideZone = shouldBeInside
        onChange(shouldBeInside)
    }

    private func finish(onChange: @escaping @MainActor (Bool) -> Void) {
        guard isInsideZone else { return }
        isInsideZone = false
        onChange(false)
    }

    nonisolated func stop() {
        dragMonitor.map { NSEvent.removeMonitor($0) }
        mouseUpMonitor.map { NSEvent.removeMonitor($0) }
        dragMonitor = nil
        mouseUpMonitor = nil
    }
}

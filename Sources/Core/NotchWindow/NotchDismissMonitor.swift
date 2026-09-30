import AppKit
import Carbon.HIToolbox

/// Regroupe les monitors temporaires installés uniquement pendant l'état `expanded`.
@MainActor
final class NotchDismissMonitor {
    nonisolated(unsafe) private var globalClickMonitor: Any?
    nonisolated(unsafe) private var globalEscapeMonitor: Any?
    nonisolated(unsafe) private var localInteractionMonitor: Any?

    func start(window: NSWindow, onDismiss: @escaping @MainActor () -> Void) {
        guard globalClickMonitor == nil, localInteractionMonitor == nil else { return }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in
            Task { @MainActor in onDismiss() }
        }
        globalEscapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            Task { @MainActor in onDismiss() }
        }
        localInteractionMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
        ) { [weak window] event in
            if event.type == .keyDown, event.keyCode == UInt16(kVK_Escape) {
                onDismiss()
                return nil
            }
            if event.type != .keyDown, event.window !== window {
                onDismiss()
            }
            return event
        }
    }

    nonisolated func stop() {
        globalClickMonitor.map { NSEvent.removeMonitor($0) }
        globalEscapeMonitor.map { NSEvent.removeMonitor($0) }
        localInteractionMonitor.map { NSEvent.removeMonitor($0) }
        globalClickMonitor = nil
        globalEscapeMonitor = nil
        localInteractionMonitor = nil
    }
}

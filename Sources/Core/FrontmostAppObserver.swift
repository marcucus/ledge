import AppKit

/// Observe l'application au premier plan pour permettre des profils de modules par app.
///
/// S'abonne à `NSWorkspace` et expose la bundle identifier courante. Le démarrage capture
/// immédiatement l'app active afin que `currentBundleID` soit correct avant la première
/// notification.
@MainActor
public final class FrontmostAppObserver {
    public private(set) var currentBundleID: String?
    public var onActiveAppChange: ((String?) -> Void)?

    private var observer: NSObjectProtocol?

    public init() {
        currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    public func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor [weak self] in
                self?.handleActivation(bundleID: app?.bundleIdentifier)
            }
        }
    }

    public func stop() {
        observer.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observer = nil
    }

    private func handleActivation(bundleID: String?) {
        guard bundleID != currentBundleID else { return }
        currentBundleID = bundleID
        onActiveAppChange?(bundleID)
    }

    deinit {
        observer.map { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }
}

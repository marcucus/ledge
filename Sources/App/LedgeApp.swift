import AppKit

@main
struct LedgeApp {
    /// static let assure que le delegate reste en vie (NSApplicationDelegate est weak)
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
}

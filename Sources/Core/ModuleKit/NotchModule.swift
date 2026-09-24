import SwiftUI

@MainActor
public protocol NotchModule: AnyObject {
    var id: String { get }
    var tabIcon: String { get }
    var tabLabel: LocalizedStringKey { get }
    func start()
    func stop()
    func makePeekView() -> AnyView
    func makeContentView() -> AnyView
}

public extension NotchModule {
    func stop() {}
    func makePeekView() -> AnyView {
        AnyView(EmptyView())
    }

    func makeContentView() -> AnyView {
        AnyView(EmptyView())
    }
}

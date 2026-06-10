import SwiftUI

public protocol NotchModule: AnyObject {
    var id: String { get }
    var tabIcon: String { get }
    var tabLabel: LocalizedStringKey { get }
    func start()
    func makePeekView() -> AnyView
    func makeContentView() -> AnyView
}

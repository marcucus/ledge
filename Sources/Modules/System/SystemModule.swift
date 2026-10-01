import Core
import SwiftUI

// MARK: — SystemModule

@MainActor
@Observable
public final class SystemModule: NotchModule {
    public let id = "system"

    // MARK: — Observed state

    private(set) var battery = BatteryStats.unavailable
    // Le module n'est plus un onglet. Il ne conserve que la batterie, utilisée comme statut
    // transverse dans la NavBar. Les jauges, toggles et lanceur historiques ont été retirés.

    @ObservationIgnored private let batterySource = BatterySource()
    @ObservationIgnored private nonisolated(unsafe) var _batterySource: BatterySource

    // MARK: — Init

    public init() {
        _batterySource = batterySource
    }

    deinit {
        _batterySource.stop()
    }

    // MARK: — NotchModule

    public func start() {
        batterySource.onUpdate = { [weak self] stats in
            Task { @MainActor [weak self] in self?.battery = stats }
        }
        batterySource.start()
    }

    public func stop() {
        batterySource.stop()
    }
}

// MARK: — NotchModule protocol conformance

public extension SystemModule {
    var tabIcon: String {
        "cpu"
    }

    var tabLabel: LocalizedStringKey {
        "module.system.label"
    }

    func makePeekView() -> AnyView {
        AnyView(SystemPeekView(module: self))
    }

    func makeContentView() -> AnyView {
        AnyView(SystemPeekView(module: self))
    }
}

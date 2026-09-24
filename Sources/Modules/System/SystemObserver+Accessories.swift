import Foundation
import IOKit

// MARK: — AccessoryBattery

/// Snapshot of a connected Bluetooth accessory's battery level(s).
///
/// Most accessories (mouse, keyboard, headset) report a single `percentage`.
/// AirPods-style accessories with a case report `left`/`right`/`case` separately
/// instead, in which case `percentage` is nil.
public struct AccessoryBattery: Identifiable, Equatable {
    public var id: String { name }

    public let name: String
    public let percentage: Int?
    public let left: Int?
    public let right: Int?
    public let caseBattery: Int?

    public init(
        name: String,
        percentage: Int? = nil,
        left: Int? = nil,
        right: Int? = nil,
        caseBattery: Int? = nil
    ) {
        self.name = name
        self.percentage = percentage
        self.left = left
        self.right = right
        self.caseBattery = caseBattery
    }

    /// `true` when this accessory reports split left/right/case levels (e.g. AirPods)
    /// rather than a single overall percentage.
    public var hasSplitLevels: Bool {
        left != nil || right != nil || caseBattery != nil
    }
}

/// Couche bas niveau de la batterie des accessoires Bluetooth (AirPods, souris, clavier...).
/// PRIVATE API: aucune API publique documentée n'expose ce niveau ; on interroge l'IORegistry
/// pour le service "AppleDeviceManagementHIDEventService" comme le font les utilitaires tiers
/// (AirBuddy, iStat Menus). Échoue proprement (liste vide) si rien n'est trouvé ou si une
/// propriété attendue est absente.
extension SystemObserver {
    nonisolated static func currentAccessoryBatteries() -> [AccessoryBattery] {
        guard let matching = IOServiceMatching("AppleDeviceManagementHIDEventService") else { return [] }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var batteries: [AccessoryBattery] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let battery = accessoryBattery(forService: service) {
                batteries.append(battery)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return batteries
    }

    /// Reads the battery propert(ies) of a single matched IORegistry service.
    /// Returns nil if no usable name or battery property is present.
    private nonisolated static func accessoryBattery(forService service: io_object_t) -> AccessoryBattery? {
        guard let name = stringProperty(service, key: "DeviceName") ?? stringProperty(service, key: "Product") else {
            return nil
        }

        let left = intProperty(service, key: "BatteryPercentLeft")
        let right = intProperty(service, key: "BatteryPercentRight")
        let caseBattery = intProperty(service, key: "BatteryPercentCase")
        let single = intProperty(service, key: "BatteryPercent")

        guard single != nil || left != nil || right != nil || caseBattery != nil else { return nil }

        return AccessoryBattery(name: name, percentage: single, left: left, right: right, caseBattery: caseBattery)
    }

    private nonisolated static func stringProperty(_ service: io_object_t, key: String) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return value.takeRetainedValue() as? String
    }

    private nonisolated static func intProperty(_ service: io_object_t, key: String) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return value.takeRetainedValue() as? Int
    }
}

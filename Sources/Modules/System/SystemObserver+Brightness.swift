import CoreGraphics
import Foundation
import IOKit.graphics

/// Couche bas niveau de la luminosité écran.
/// PRIVATE API: DisplayServices — framework privé (Apple Silicon), peut casser entre
/// versions de macOS ; repli IOKit (Intel). Échoue proprement si rien n'est disponible.
extension SystemObserver {
    private typealias BrightnessGetter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias BrightnessSetter = @convention(c) (UInt32, Float) -> Int32

    private nonisolated(unsafe) static var dsGet: BrightnessGetter?
    private nonisolated(unsafe) static var dsSet: BrightnessSetter?
    private nonisolated(unsafe) static var dsLoaded = false

    nonisolated static func loadDisplayServices() {
        guard !dsLoaded else { return }
        dsLoaded = true
        // PRIVATE API: chargement dynamique — échoue proprement (dsGet/dsSet restent nil).
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        ) else { return }
        if let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            dsGet = unsafeBitCast(symbol, to: BrightnessGetter.self)
        }
        if let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            dsSet = unsafeBitCast(symbol, to: BrightnessSetter.self)
        }
    }

    nonisolated static func currentBrightness() -> Double {
        // Essai 1 : IOKit (Intel)
        var value: Float = -1
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"))
        if service != 0 {
            IODisplayGetFloatParameter(service, 0, "brightness" as CFString, &value)
            IOObjectRelease(service)
            if value >= 0 { return Double(value) }
        }
        // Essai 2 : DisplayServices (Apple Silicon)
        if let get = dsGet {
            var displayValue: Float = -1
            if get(CGMainDisplayID(), &displayValue) == 0, displayValue >= 0 {
                return Double(displayValue)
            }
        }
        return -1
    }

    nonisolated static func setBrightness(_ value: Float) {
        let clamped = clamp(value)
        if let set = dsSet {
            _ = set(CGMainDisplayID(), clamped)
            return
        }
        // Fallback IOKit (Intel)
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayConnect"))
        if service != 0 {
            IODisplaySetFloatParameter(service, 0, "brightness" as CFString, clamped)
            IOObjectRelease(service)
        }
    }
}

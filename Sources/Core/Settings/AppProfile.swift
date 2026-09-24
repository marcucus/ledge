import Foundation

/// Profil de visibilité des modules pour une application donnée.
///
/// Quand l'app dont la bundle ID correspond à `bundleID` est au premier plan, `moduleOrder`
/// et `disabledModuleIDs` remplacent les réglages globaux équivalents (voir
/// `NotchController.visibleModules`). En l'absence de profil correspondant, le comportement
/// global continue de s'appliquer.
public struct AppProfile: Codable, Identifiable, Equatable {
    public let id: UUID
    public var bundleID: String
    public var moduleOrder: [String]
    public var disabledModuleIDs: Set<String>

    public init(
        id: UUID = UUID(),
        bundleID: String,
        moduleOrder: [String],
        disabledModuleIDs: Set<String> = []
    ) {
        self.id = id
        self.bundleID = bundleID
        self.moduleOrder = moduleOrder
        self.disabledModuleIDs = disabledModuleIDs
    }
}

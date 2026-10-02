@testable import App
import Testing

@MainActor
struct AppModuleAssemblyTests {
    @Test func assemblyRegistersSevenNavigationModulesAndKeepsSystemTransverse() {
        let assembly = AppModuleAssembly()
        let navigationIDs = assembly.navigationModules.map(\.id)

        #expect(navigationIDs == [
            "media", "timers", "dropzone", "clipboard", "shortcuts", "calendar", "notes",
        ])
        #expect(!navigationIDs.contains(assembly.systemModule.id))
        #expect(assembly.systemModule.id == "system")
    }
}

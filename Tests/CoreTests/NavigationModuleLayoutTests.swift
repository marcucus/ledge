@testable import Core
import Testing

struct NavigationModuleLayoutTests {
    @Test func panoramicKeepsTwoModulesBesideGridOnLeadingShoulder() {
        let count = NavigationModuleLayout.leadingModuleCount(
            moduleCount: 2,
            panelWidth: 920,
            notchReserve: 204,
            tabWidth: 48,
            showsGridButton: true
        )

        #expect(count == 2)
    }

    @Test func onlyOverflowMovesPastNotch() {
        let count = NavigationModuleLayout.leadingModuleCount(
            moduleCount: 7,
            panelWidth: 744,
            notchReserve: 204,
            tabWidth: 44,
            showsGridButton: true
        )

        #expect(count == 4)
    }

    @Test func gridButtonConsumesOneLeadingSlot() {
        let withoutGrid = NavigationModuleLayout.leadingModuleCount(
            moduleCount: 4,
            panelWidth: 580,
            notchReserve: 204,
            tabWidth: 40,
            showsGridButton: false
        )
        let withGrid = NavigationModuleLayout.leadingModuleCount(
            moduleCount: 4,
            panelWidth: 580,
            notchReserve: 204,
            tabWidth: 40,
            showsGridButton: true
        )

        #expect(withoutGrid == 4)
        #expect(withGrid == 3)
    }
}

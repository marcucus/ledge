import CoreGraphics

enum NavigationModuleLayout {
    static func leadingModuleCount(
        moduleCount: Int,
        panelWidth: CGFloat,
        notchReserve: CGFloat,
        tabWidth: CGFloat,
        showsGridButton: Bool
    ) -> Int {
        guard moduleCount > 0 else { return 0 }

        let shoulderWidth = max(0, (panelWidth - notchReserve) / 2)
        let usableWidth = max(0, shoulderWidth - 8)
        let itemCapacity = max(0, Int((usableWidth + 2) / (tabWidth + 2)))
        let moduleCapacity = itemCapacity - (showsGridButton ? 1 : 0)
        return min(moduleCount, max(0, moduleCapacity))
    }
}

import SwiftUI

struct ExpandedView: View {
    var controller: NotchController

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider().opacity(0.4)
            contentArea
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(controller.modules.map(ModuleItem.init), id: \.id) { item in
                moduleTabButton(item)
            }
            Spacer()
            iconButton(icon: "gear", label: "action.settings") { }
            iconButton(icon: "xmark", label: "action.close") { controller.dismiss() }
        }
        .padding(.horizontal, 8)
        .frame(height: Layout.tabBarHeight)
    }

    private func moduleTabButton(_ item: ModuleItem) -> some View {
        Button { controller.selectModule(id: item.id) } label: {
            Image(systemName: item.base.tabIcon)
                .imageScale(.medium)
                .foregroundStyle(item.id == controller.selectedModuleID ? .primary : .secondary)
                .frame(width: 36, height: Layout.tabBarHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.base.tabLabel)
    }

    private func iconButton(icon: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .frame(width: 28, height: Layout.tabBarHeight)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var contentArea: some View {
        Group {
            if let module = controller.selectedModule {
                module.makeContentView()
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ModuleItem {
    let id: String
    let base: any NotchModule
    init(_ module: any NotchModule) { id = module.id; base = module }
}

private enum Layout {
    static let tabBarHeight: CGFloat = 44
}

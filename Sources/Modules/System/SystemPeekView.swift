import SwiftUI

// MARK: — SystemPeekView

/// Compact battery gauge shown in the notch peek (hover) state.
struct SystemPeekView: View {
    var module: SystemModule

    var body: some View {
        HStack(spacing: 6) {
            batteryIcon
            if let pct = module.battery.percentage {
                Text("\(pct)%")
                    .font(.caption.monospacedDigit())
                if module.battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .imageScale(.small)
                        .foregroundStyle(.green)
                }
            }
        }
        .imageScale(.small)
        .padding(.trailing, 4)
    }

    // MARK: — Battery icon

    private var batteryIcon: some View {
        Image(systemName: batteryIconName)
            .imageScale(.small)
            .foregroundStyle(batteryColor)
    }

    private var batteryIconName: String {
        guard let pct = module.battery.percentage else { return "battery.0" }
        switch pct {
        case 75...: return module.battery.isCharging ? "battery.100.bolt" : "battery.100"
        case 50...: return "battery.75"
        case 25...: return "battery.50"
        default:    return "battery.25"
        }
    }

    private var batteryColor: Color {
        guard let pct = module.battery.percentage else { return .secondary }
        if module.battery.isCharging { return .green }
        return pct < 20 ? .red : .primary
    }

    // MARK: — CPU badge

    private var cpuBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "cpu")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            Text("\(Int(module.cpu.usage * 100))%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

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
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize()
                if module.battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .fixedSize()
        .padding(.trailing, 4)
    }

    // MARK: — Battery icon

    private var batteryIcon: some View {
        Image(systemName: batteryIconName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(batteryColor)
    }

    private var batteryIconName: String {
        guard let pct = module.battery.percentage else { return "battery.0" }
        switch pct {
        case 75...: return module.battery.isCharging ? "battery.100.bolt" : "battery.100"
        case 50...: return "battery.75"
        case 25...: return "battery.50"
        default: return "battery.25"
        }
    }

    private var batteryColor: Color {
        guard let pct = module.battery.percentage else { return .white.opacity(0.6) }
        if module.battery.isCharging { return .green }
        return pct < 20 ? .red : .white.opacity(0.9)
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

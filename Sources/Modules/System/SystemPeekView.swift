import Core
import SwiftUI

// MARK: — SystemPeekView

/// Compact battery gauge shown in the notch peek (hover) state.
struct SystemPeekView: View {
    var module: SystemModule

    var body: some View {
        HStack(spacing: 5) {
            batteryIcon
            if let pct = module.battery.percentage {
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .fixedSize()
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(statusBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: — Battery icon

    private var batteryIcon: some View {
        Image(systemName: batteryIconName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(batteryColor)
    }

    private var batteryIconName: String {
        guard let pct = module.battery.percentage else { return "battery.0" }
        if module.battery.isCharging { return "battery.100.bolt" }
        switch pct {
        case 75...: return "battery.100"
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

    private var statusBackground: Color {
        guard let pct = module.battery.percentage else { return .white.opacity(0.035) }
        if module.battery.isCharging { return .green.opacity(0.1) }
        return pct < 20 ? .red.opacity(0.11) : .white.opacity(0.045)
    }

    private var accessibilityLabel: Text {
        guard let pct = module.battery.percentage else {
            return Text("system.gauge.battery", bundle: localizationBundle)
        }
        let key = module.battery.isCharging
            ? "system.battery.accessibility.charging"
            : "system.battery.accessibility"
        let format = NSLocalizedString(key, bundle: localizationBundle, comment: "")
        return Text(String(format: format, pct))
    }
}

import AppKit
import Core
import SwiftUI

// MARK: — SystemContentView

struct SystemContentView: View {
    var module: SystemModule
    private var settings: SettingsStore { SettingsStore.shared }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                gaugesSection
                Divider().opacity(0.4)
                togglesSection
                Divider().opacity(0.4)
                launcherSection
            }
            .padding(12)
        }
        .onAppear { module.beginPolling() }
        .onDisappear { module.endPolling() }
    }

    // MARK: — Gauges

    private var gaugesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("system.section.gauges")
            if settings.systemShowBattery { batteryRow }
            if settings.systemShowCPU { cpuRow }
            if settings.systemShowRAM { ramRow }
            if settings.systemShowNetwork { networkRow }
            if settings.systemShowMicrophoneIndicator { microphoneRow }
            if settings.systemShowAccessoryBattery, !module.accessoryBatteries.isEmpty {
                accessoryBatteryRows
            }
        }
    }

    private var microphoneRow: some View {
        HStack {
            Image(systemName: "mic.fill")
                .imageScale(.small)
                .foregroundStyle(module.isMicrophoneActive ? Color.red : Color.secondary)
            Text("system.gauge.microphone", bundle: localizationBundle)
            Spacer()
            Text(
                module.isMicrophoneActive
                    ? "system.microphone.active"
                    : "system.microphone.inactive",
                bundle: localizationBundle
            )
            .foregroundStyle(module.isMicrophoneActive ? .red : .secondary)
        }
        .font(.caption)
    }

    private var accessoryBatteryRows: some View {
        ForEach(module.accessoryBatteries) { accessory in
            accessoryBatteryRow(accessory)
        }
    }

    private func accessoryBatteryRow(_ accessory: AccessoryBattery) -> some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right").imageScale(.small)
            Text(accessory.name)
                .lineLimit(1)
            Spacer()
            if accessory.hasSplitLevels {
                HStack(spacing: 6) {
                    if let left = accessory.left { Text("L \(left)%") }
                    if let right = accessory.right { Text("R \(right)%") }
                    if let caseBattery = accessory.caseBattery {
                        HStack(spacing: 2) {
                            Image(systemName: "case.fill").imageScale(.small)
                            Text("\(caseBattery)%")
                        }
                    }
                }
                .monospacedDigit()
                .foregroundStyle(.secondary)
            } else if let pct = accessory.percentage {
                Text("\(pct)%").monospacedDigit()
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var batteryRow: some View {
        HStack {
            Image(systemName: "battery.100").imageScale(.small)
            Text("system.gauge.battery", bundle: localizationBundle)
            Spacer()
            if let pct = module.battery.percentage {
                Text("\(pct)%").monospacedDigit()
                if module.battery.isCharging {
                    Text("system.battery.charging", bundle: localizationBundle).foregroundStyle(.green)
                }
                if let cycles = module.battery.cycleCount {
                    Text("\(cycles) cyc.").foregroundStyle(.secondary)
                }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private var cpuRow: some View {
        HStack {
            Image(systemName: "cpu").imageScale(.small)
            Text("system.gauge.cpu", bundle: localizationBundle)
            Spacer()
            SparklineView(samples: module.cpu.history, color: .blue)
                .frame(width: 60, height: 16)
            Text("\(Int(module.cpu.usage * 100))%").monospacedDigit()
        }
        .font(.caption)
    }

    private var ramRow: some View {
        HStack {
            Image(systemName: "memorychip").imageScale(.small)
            Text("system.gauge.ram", bundle: localizationBundle)
            Spacer()
            ProgressView(value: module.ram.usageFraction)
                .progressViewStyle(.linear)
                .frame(width: 60)
            Text(String(format: "%.1f/%.0fG", module.ram.usedGB, module.ram.totalGB))
                .monospacedDigit()
        }
        .font(.caption)
    }

    private var networkRow: some View {
        HStack {
            Image(systemName: "network").imageScale(.small)
            Text("system.gauge.network", bundle: localizationBundle)
            Spacer()
            Text("↓\(module.network.downloadLabel) ↑\(module.network.uploadLabel)")
                .monospacedDigit()
                .font(.caption2)
        }
        .font(.caption)
    }

    // MARK: — Toggles

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("system.section.toggles")
            HStack(spacing: 8) {
                ForEach(module.toggles) { toggle in
                    ToggleButton(toggle: toggle) {
                        Task { await toggle.action() }
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: — Launcher

    private var launcherSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("system.section.launcher")
            if module.launcherItems.isEmpty {
                Text("—").font(.caption).foregroundStyle(.tertiary)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                    spacing: 8
                ) {
                    ForEach(module.launcherItems) { item in
                        LauncherItemView(item: item) {
                            module.launch(item: item)
                        }
                    }
                }
            }
        }
    }

    // MARK: — Helpers

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key, bundle: localizationBundle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

// MARK: — SparklineView

private struct SparklineView: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard samples.count > 1 else { return }
                let width = geo.size.width
                let height = geo.size.height
                let step = width / CGFloat(samples.count - 1)
                for (index, sample) in samples.enumerated() {
                    let point = CGPoint(x: CGFloat(index) * step, y: height - CGFloat(sample) * height)
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}

// MARK: — ToggleButton

private struct ToggleButton: View {
    let toggle: QuickToggle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: toggle.icon)
                    .imageScale(.medium)
                Text(LocalizedStringKey(toggle.labelKey), bundle: localizationBundle)
                    .font(.caption2)
            }
            .frame(width: 52, height: 48)
            .background(toggle.isOn ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        toggle.isOn ? Color.accentColor.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(toggle.isOn ? .primary : .secondary)
    }
}

// MARK: — LauncherItemView

private struct LauncherItemView: View {
    let item: AppLauncherItem
    let action: () -> Void

    @State private var icon: NSImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Group {
                    if let icon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "app")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                Text(item.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .task { icon = NSWorkspace.shared.icon(forFile: item.bundleURL.path) }
    }
}

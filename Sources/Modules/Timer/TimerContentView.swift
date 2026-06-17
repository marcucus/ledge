import Core
import SwiftUI

public struct TimerContentView: View {
    public var module: TimerModule
    @State private var customMinutes: String = ""
    @State private var showCustomInput = false

    private let presets: [TimeInterval] = [5 * 60, 10 * 60, 25 * 60, 60 * 60]

    public init(module: TimerModule) {
        self.module = module
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            presetRow
            if showCustomInput { customInputRow }
            Divider().opacity(0.4)
            timerList
            pomodoroButton
        }
        .padding(12)
    }

    // MARK: — Presets

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(presets, id: \.self) { duration in
                presetButton(duration: duration)
            }
            Spacer()
            Button {
                showCustomInput.toggle()
            } label: {
                Image(systemName: "plus.circle")
                    .imageScale(.medium)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("timer.action.custom", bundle: localizationBundle))
        }
    }

    private func presetButton(duration: TimeInterval) -> some View {
        let minutes = Int(duration / 60)
        return Button {
            module.addTimer(
                label: String(
                    format: NSLocalizedString("timer.preset.minutes", bundle: localizationBundle, comment: ""),
                    minutes
                ),
                duration: duration
            )
        } label: {
            Text("\(minutes)m")
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: — Custom input

    private var customInputRow: some View {
        HStack(spacing: 8) {
            TextField(
                NSLocalizedString("timer.custom.placeholder", bundle: localizationBundle, comment: ""),
                text: $customMinutes
            )
            .textFieldStyle(.plain)
            .font(.footnote)
            .frame(width: 60)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            Button {
                addCustomTimer()
            } label: {
                Text("timer.action.add", bundle: localizationBundle)
                    .font(.footnote.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
    }

    private func addCustomTimer() {
        guard let minutes = Int(customMinutes), minutes > 0 else { return }
        let duration = TimeInterval(minutes * 60)
        module.addTimer(
            label: String(
                format: NSLocalizedString("timer.preset.minutes", bundle: localizationBundle, comment: ""),
                minutes
            ),
            duration: duration
        )
        customMinutes = ""
        showCustomInput = false
    }

    // MARK: — Timer list

    @ViewBuilder
    private var timerList: some View {
        if module.entries.isEmpty {
            Text("timer.peek.idle", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 4)
        } else {
            ForEach(module.entries) { entry in
                TimerRowView(entry: entry, module: module)
            }
        }
    }

    // MARK: — Pomodoro

    private var pomodoroButton: some View {
        Button {
            module.startPomodoro()
        } label: {
            Label(
                NSLocalizedString("timer.pomodoro.start", bundle: localizationBundle, comment: ""),
                systemImage: "tomato"
            )
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.orange.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
    }
}

// MARK: — Timer row

private struct TimerRowView: View {
    let entry: TimerEntry
    let module: TimerModule

    private var formatted: String {
        let total = max(0, Int(entry.remaining))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    var body: some View {
        HStack(spacing: 8) {
            progressArc
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                Text(formatted)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            controlButtons
        }
        .padding(.vertical, 2)
    }

    private var progressArc: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 1.5
            var track = Path()
            track.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(270),
                clockwise: false
            )
            context.stroke(track, with: .color(.white.opacity(0.15)), lineWidth: 2)
            guard entry.progress > 0 else { return }
            var progress = Path()
            progress.addArc(
                center: center, radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * entry.progress),
                clockwise: false
            )
            context.stroke(progress, with: .color(.accentColor), lineWidth: 2)
        }
        .frame(width: 22, height: 22)
    }

    private var controlButtons: some View {
        HStack(spacing: 4) {
            if entry.isRunning {
                Button { module.send(.pause(id: entry.id)) } label: {
                    Image(systemName: "pause.fill").imageScale(.small)
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            } else {
                Button { module.send(.start(id: entry.id)) } label: {
                    Image(systemName: "play.fill").imageScale(.small)
                }
                .buttonStyle(.plain).foregroundStyle(Color.accentColor)
            }
            Button { module.send(.reset(id: entry.id)) } label: {
                Image(systemName: "arrow.counterclockwise").imageScale(.small)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            Button { module.removeTimer(id: entry.id) } label: {
                Image(systemName: "xmark").imageScale(.small)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
        }
    }
}

import Core
import SwiftUI

public struct TimerPeekView: View {
    public var module: TimerModule

    private var activeEntry: TimerEntry? {
        module.entries.first { $0.isRunning || $0.isPaused }
    }

    public init(module: TimerModule) {
        self.module = module
    }

    public var body: some View {
        HStack(spacing: 10) {
            if let entry = activeEntry {
                arcProgress(entry: entry)
                timeLabel(entry: entry)
            } else {
                Text("timer.peek.idle", bundle: localizationBundle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }

    private func arcProgress(entry: TimerEntry) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 2
            let startAngle = Angle.degrees(-90)
            let endAngle = Angle.degrees(-90 + 360 * entry.progress)

            var trackPath = Path()
            trackPath.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: .degrees(270),
                clockwise: false
            )
            context.stroke(trackPath, with: .color(.white.opacity(0.15)), lineWidth: 2.5)

            var progressPath = Path()
            progressPath.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: false
            )
            context.stroke(progressPath, with: .color(.accentColor), lineWidth: 2.5)
        }
        .frame(width: 28, height: 28)
    }

    private func timeLabel(entry: TimerEntry) -> some View {
        Text(formatted(entry.remaining))
            .font(.callout.monospacedDigit().weight(.medium))
            .foregroundStyle(.primary)
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

import Core
import SwiftUI

public struct TimerContentView: View {
    public var module: TimerModule

    @State private var hours = 0
    @State private var minutes = 25
    @State private var seconds = 0

    /// Raccourcis « un tap = timer lancé » (en secondes).
    private let quickPresets: [Int] = [5 * 60, 10 * 60, 25 * 60, 60 * 60]

    /// Hauteur d'une ligne de molette (partagée entre la molette et la bande de surbrillance).
    private let wheelRowHeight: CGFloat = 22

    public init(module: TimerModule) {
        self.module = module
    }

    public var body: some View {
        HStack(spacing: 12) {
            setupColumn
            Divider().opacity(0.4)
            runningColumn
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: — Left column : timers en cours

    private var runningColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("timer.section.active", bundle: localizationBundle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if module.entries.isEmpty {
                Text("timer.peek.idle", bundle: localizationBundle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                timerList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: — Right column : réglage du timer

    private var setupColumn: some View {
        VStack(spacing: 8) {
            wheelPicker
            startButton
            quickRow
            pomodoroButton
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Wheel picker

    private var wheelPicker: some View {
        HStack(spacing: 0) {
            wheelUnit(values: Array(0...23), selection: $hours, unit: "h")
            colon
            wheelUnit(values: Array(0...59), selection: $minutes, unit: "m")
            colon
            wheelUnit(values: Array(0...59), selection: $seconds, unit: "s")
        }
        .overlay(centerBand)
    }

    private func wheelUnit(values: [Int], selection: Binding<Int>, unit: String) -> some View {
        VStack(spacing: 2) {
            WheelColumn(values: values, selection: selection, rowHeight: wheelRowHeight)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var colon: some View {
        Text(":")
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            // Aligné sur le centre des colonnes (la ligne sélectionnée), pas sur le label d'unité.
            .frame(height: wheelRowHeight * 3, alignment: .center)
    }

    /// Bande de surbrillance derrière la ligne centrale (sélectionnée) des molettes.
    /// Calée en haut + décalée d'une ligne pour tomber pile sur la rangée du milieu.
    private var centerBand: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.white.opacity(0.08))
            .frame(height: wheelRowHeight)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, wheelRowHeight)
            .allowsHitTesting(false)
    }

    // MARK: — Start

    private var startButton: some View {
        Button(action: startFromWheel) {
            Label {
                Text("timer.action.start", bundle: localizationBundle)
            } icon: {
                Image(systemName: "play.fill")
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.accentColor.opacity(totalSeconds > 0 ? 0.9 : 0.3), in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(totalSeconds == 0)
    }

    private var totalSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private func startFromWheel() {
        module.addAndStart(label: wheelLabel, duration: TimeInterval(totalSeconds))
    }

    private var wheelLabel: String {
        hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: — Quick presets + Pomodoro

    /// Raccourcis de durée (un tap = timer lancé).
    private var quickRow: some View {
        HStack(spacing: 6) {
            ForEach(quickPresets, id: \.self) { duration in
                quickChip(duration: duration)
            }
        }
    }

    private func quickChip(duration: Int) -> some View {
        let mins = duration / 60
        return Button {
            module.addAndStart(label: String(format: "%d:00", mins), duration: TimeInterval(duration))
        } label: {
            Text("\(mins)m")
                .font(.footnote.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Pomodoro explicitement libellé (l'ancienne tomate seule n'était pas claire).
    private var pomodoroButton: some View {
        Button {
            module.startPomodoro()
        } label: {
            Label {
                Text("timer.pomodoro.start", bundle: localizationBundle)
            } icon: {
                Image(systemName: "tomato")
            }
            .font(.footnote.weight(.medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(.orange.opacity(0.15), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.orange)
    }

    // MARK: — Timer list

    private var timerList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(module.entries) { entry in
                    TimerRowView(entry: entry, module: module)
                }
            }
        }
    }
}

// MARK: — Wheel column

/// Molette défilante d'une unité (heures/minutes/secondes), avec snapping natif macOS 14.
/// La valeur centrée est liée à `selection`.
private struct WheelColumn: View {
    let values: [Int]
    @Binding var selection: Int
    let rowHeight: CGFloat

    @State private var scrollID: Int?

    init(values: [Int], selection: Binding<Int>, rowHeight: CGFloat) {
        self.values = values
        self._selection = selection
        self.rowHeight = rowHeight
        // Position initiale = valeur sélectionnée → la molette est centrée dès le 1er rendu
        // (sinon `onAppear` arrive après le layout et la molette reste en haut, sur 00).
        self._scrollID = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(values, id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .font(.system(size: 18, weight: .medium, design: .rounded).monospacedDigit())
                        .frame(height: rowHeight)
                        .frame(maxWidth: .infinity)
                        .id(value)
                        .opacity(scrollID == value ? 1 : 0.3)
                        .scaleEffect(scrollID == value ? 1 : 0.82)
                        .animation(.easeOut(duration: 0.12), value: scrollID)
                }
            }
            .scrollTargetLayout()
        }
        .frame(width: 40, height: rowHeight * 3)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID, anchor: .center)
        .contentMargins(.vertical, rowHeight, for: .scrollContent)
        .onAppear { scrollID = selection }
        .onChange(of: scrollID) { _, newValue in
            if let newValue { selection = newValue }
        }
        .onChange(of: selection) { _, newValue in
            if scrollID != newValue { scrollID = newValue }
        }
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

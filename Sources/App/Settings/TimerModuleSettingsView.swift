import Core
import SwiftUI

struct TimerModuleSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section(header: Text("settings.modules.timer.pomodoro", bundle: localizationBundle)) {
                durationRow(
                    labelKey: "settings.modules.timer.workDuration",
                    value: durationBinding(\.pomodoroWorkDuration),
                    range: 1...90
                )
                durationRow(
                    labelKey: "settings.modules.timer.shortBreakDuration",
                    value: durationBinding(\.pomodoroShortBreakDuration),
                    range: 1...30
                )
                durationRow(
                    labelKey: "settings.modules.timer.longBreakDuration",
                    value: durationBinding(\.pomodoroLongBreakDuration),
                    range: 1...60
                )
            }

            Section {
                Toggle(isOn: Binding(
                    get: { store.showRingWhenTimerActive },
                    set: { store.showRingWhenTimerActive = $0 }
                )) {
                    Text("settings.modules.timer.timerRing", bundle: localizationBundle)
                }

                Toggle(isOn: Binding(
                    get: { store.timerSoundEnabled },
                    set: { store.timerSoundEnabled = $0 }
                )) {
                    Text("settings.modules.timer.sound", bundle: localizationBundle)
                }

                Toggle(isOn: Binding(
                    get: { store.timerAlertVisualOnly },
                    set: { store.timerAlertVisualOnly = $0 }
                )) {
                    Text("settings.modules.timer.visualOnly", bundle: localizationBundle)
                }
            }

            finishedPeekSection
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.timers.label", bundle: localizationBundle))
    }

    /// Doc 13, Jalon 3, item 20 : peek configurable à la fin d'un minuteur, en plus de la
    /// notification système (utile quand celle-ci est discrète ou masquée par Ne pas déranger).
    private var finishedPeekSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.timerFinishedPeekEnabled },
                set: { store.timerFinishedPeekEnabled = $0 }
            )) {
                Text("settings.modules.timer.finishedPeek", bundle: localizationBundle)
            }

            if store.timerFinishedPeekEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.modules.timer.finishedPeek.duration", bundle: localizationBundle)
                    HStack {
                        Slider(value: peekDurationBinding, in: 2...10, step: 1)
                        Text(String(format: "%.0f s", store.timerFinishedPeekDuration))
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        } footer: {
            Text("settings.modules.timer.finishedPeek.hint", bundle: localizationBundle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var peekDurationBinding: Binding<Double> {
        Binding(get: { store.timerFinishedPeekDuration }, set: { store.timerFinishedPeekDuration = $0 })
    }

    private func durationRow(labelKey: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(labelKey), bundle: localizationBundle)
            HStack {
                Slider(value: value, in: range, step: 1)
                Text(String(
                    format: "%.0f %@",
                    value.wrappedValue,
                    NSLocalizedString("settings.modules.timer.minutes", bundle: localizationBundle, comment: "")
                ))
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }

    private func durationBinding(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Double>) -> Binding<Double> {
        Binding(get: { store[keyPath: keyPath] }, set: { store[keyPath: keyPath] = $0 })
    }
}

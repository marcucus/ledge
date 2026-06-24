import Core
import SwiftUI

struct TimerModuleSettingsView: View {
    var store: SettingsStore

    var body: some View {
        Form {
            Section(header: Text("settings.modules.timer.pomodoro", bundle: localizationBundle)) {
                durationRow(
                    labelKey: "settings.modules.timer.workDuration",
                    value: Binding(get: { store.pomodoroWorkDuration }, set: { store.pomodoroWorkDuration = $0 }),
                    range: 1...90
                )
                durationRow(
                    labelKey: "settings.modules.timer.shortBreakDuration",
                    value: Binding(get: { store.pomodoroShortBreakDuration }, set: { store.pomodoroShortBreakDuration = $0 }),
                    range: 1...30
                )
                durationRow(
                    labelKey: "settings.modules.timer.longBreakDuration",
                    value: Binding(get: { store.pomodoroLongBreakDuration }, set: { store.pomodoroLongBreakDuration = $0 }),
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
        }
        .formStyle(.grouped)
        .navigationTitle(Text("module.timers.label", bundle: localizationBundle))
    }

    private func durationRow(labelKey: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(labelKey), bundle: localizationBundle)
            HStack {
                Slider(value: value, in: range, step: 1)
                Text(String(format: "%.0f %@", value.wrappedValue,
                            NSLocalizedString("settings.modules.timer.minutes", bundle: localizationBundle, comment: "")))
                    .monospacedDigit()
                    .frame(width: 56, alignment: .trailing)
            }
        }
    }
}

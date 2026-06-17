import Core
import SwiftUI

struct AboutSettingsView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "© 2024 Adrien Marques"
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("settings.about.appName", bundle: localizationBundle)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("Ledge")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("settings.about.version", bundle: localizationBundle)
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("settings.about.copyright", bundle: localizationBundle)
                    Spacer()
                    Text(copyright)
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    // Placeholder — update check not yet implemented
                } label: {
                    Text("settings.about.checkUpdates", bundle: localizationBundle)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.about", bundle: localizationBundle))
    }
}

import AppKit
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

    private func loadLogoFromBundle() -> NSImage? {
        guard let url = Bundle.module.url(forResource: "ledgelogo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    if let img = NSImage(named: "ledgelogo") ?? loadLogoFromBundle() {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ledge")
                            .font(.title2.weight(.semibold))
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Text(copyright)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button {
                    (NSApplication.shared.delegate as? AppDelegate)?.checkForUpdates()
                } label: {
                    Text("settings.about.checkUpdates", bundle: localizationBundle)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(Text("settings.section.about", bundle: localizationBundle))
    }
}

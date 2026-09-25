import Core
import SwiftUI

struct OnboardingNotchPreview: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07))
                }

            notch
            modulePanel
                .padding(.top, 72)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.preview.accessibility", bundle: localizationBundle))
    }

    private var notch: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 18,
            bottomTrailingRadius: 18,
            topTrailingRadius: 0
        )
        .fill(.black)
        .frame(width: 138, height: 38)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(accent)
                .frame(width: 6, height: 6)
                .padding(7)
        }
    }

    private var modulePanel: some View {
        VStack(spacing: 14) {
            HStack(spacing: 18) {
                moduleIcon("music.note", isActive: false)
                moduleIcon("timer", isActive: true)
                moduleIcon("tray.and.arrow.down", isActive: false)
                moduleIcon("clipboard", isActive: false)
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text("onboarding.preview.focus", bundle: localizationBundle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("24:18")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "pause.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.09), in: Circle())
            }
            .padding(16)
            .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(22)
    }

    private func moduleIcon(_ name: String, isActive: Bool) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isActive ? .white : .secondary)
            .frame(width: 30, height: 30)
            .background(isActive ? accent : Color.clear, in: RoundedRectangle(cornerRadius: 9))
    }
}

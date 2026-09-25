import Core
import SwiftUI

struct OnboardingView: View {
    let onFinish: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = OnboardingStep.welcome

    private let accent = Color(red: 0.48, green: 0.40, blue: 1.0)

    var body: some View {
        VStack(spacing: 0) {
            header
            page
                .id(step)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .trailing)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 42)
            footer
        }
        .frame(width: 680, height: 470)
        .background(background)
        .environment(\.colorScheme, .dark)
        .tint(accent)
    }

    private var header: some View {
        HStack(spacing: 10) {
            LedgeBrandMark(accent: accent)
            Text("notch.app.name", bundle: localizationBundle)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Spacer()
            Text(step.progressKey, bundle: localizationBundle)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:
            welcomePage
        case .interaction:
            interactionPage
        case .permissions:
            permissionsPage
        }
    }

    private var welcomePage: some View {
        HStack(spacing: 42) {
            pageCopy(
                title: "onboarding.welcome.title",
                detail: "onboarding.welcome.detail"
            )
            OnboardingNotchPreview(accent: accent)
                .frame(width: 300, height: 250)
        }
    }

    private var interactionPage: some View {
        HStack(spacing: 46) {
            pageCopy(
                title: "onboarding.interaction.title",
                detail: "onboarding.interaction.detail"
            )
            VStack(alignment: .leading, spacing: 0) {
                instructionRow(
                    icon: "cursorarrow.motionlines",
                    title: "onboarding.interaction.hover.title",
                    detail: "onboarding.interaction.hover.detail"
                )
                instructionDivider
                instructionRow(
                    icon: "hand.tap",
                    title: "onboarding.interaction.click.title",
                    detail: "onboarding.interaction.click.detail"
                )
                instructionDivider
                instructionRow(
                    icon: "option",
                    title: "onboarding.interaction.shortcut.title",
                    detail: "onboarding.interaction.shortcut.detail"
                )
            }
            .frame(width: 300)
        }
    }

    private var permissionsPage: some View {
        HStack(spacing: 48) {
            pageCopy(
                title: "onboarding.permissions.title",
                detail: "onboarding.permissions.detail"
            )
            VStack(alignment: .leading, spacing: 18) {
                permissionBenefit(icon: "hand.raised", key: "onboarding.permissions.benefit.control")
                permissionBenefit(icon: "lock.open", key: "onboarding.permissions.benefit.optional")
                permissionBenefit(icon: "gearshape", key: "onboarding.permissions.benefit.later")
            }
            .frame(width: 286, alignment: .leading)
        }
    }

    private func pageCopy(title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title, bundle: localizationBundle)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(accent)
                .frame(width: 34, height: 3)
                .clipShape(Capsule())
            Text(detail, bundle: localizationBundle)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func instructionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title), bundle: localizationBundle)
                    .font(.headline)
                Text(LocalizedStringKey(detail), bundle: localizationBundle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
    }

    private var instructionDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
            .padding(.leading, 40)
    }

    private func permissionBenefit(icon: String, key: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 28, height: 28)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(key, bundle: localizationBundle)
                .font(.callout.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                step == .welcome ? onFinish(false) : move(to: step.previous)
            } label: {
                Text(
                    step == .welcome ? "onboarding.action.skip" : "onboarding.action.back",
                    bundle: localizationBundle
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()
            stepIndicator
            Spacer()

            if step == .permissions {
                Button {
                    onFinish(true)
                } label: {
                    Text("onboarding.action.permissions", bundle: localizationBundle)
                }
                .buttonStyle(.bordered)
                Button {
                    onFinish(false)
                } label: {
                    Text("onboarding.action.finish", bundle: localizationBundle)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button {
                    move(to: step.next)
                } label: {
                    Text("onboarding.action.continue", bundle: localizationBundle)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .overlay(alignment: .top) {
            Divider().overlay(Color.white.opacity(0.08))
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 7) {
            ForEach(OnboardingStep.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == step ? accent : Color.secondary.opacity(0.3))
                    .frame(width: item == step ? 18 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.progressKey, bundle: localizationBundle))
    }

    private var background: some View {
        ZStack(alignment: .topTrailing) {
            Color(red: 0.055, green: 0.058, blue: 0.07)
            Circle()
                .fill(accent.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 90, y: -120)
        }
        .ignoresSafeArea()
    }

    private func move(to destination: OnboardingStep) {
        if reduceMotion {
            step = destination
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                step = destination
            }
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case interaction
    case permissions

    var next: OnboardingStep { OnboardingStep(rawValue: rawValue + 1) ?? self }
    var previous: OnboardingStep { OnboardingStep(rawValue: rawValue - 1) ?? self }

    var progressKey: LocalizedStringKey {
        switch self {
        case .welcome: "onboarding.progress.1"
        case .interaction: "onboarding.progress.2"
        case .permissions: "onboarding.progress.3"
        }
    }
}

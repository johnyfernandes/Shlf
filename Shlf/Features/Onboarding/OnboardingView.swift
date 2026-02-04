//
//  OnboardingView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import ActivityKit
import UIKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Query private var profiles: [UserProfile]
    @Binding var isPresented: Bool

    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedTheme: ThemeColor = .blue
    @State private var selectedGoalType: GoalType = .pagesPerDay
    @State private var goalValue: Int = 15
    @State private var skipGoalSetup = false
    @State private var liveActivitiesEnabled = true
    @State private var showUpgradeSheet = false

    private var isProUser: Bool {
        guard let profile = profiles.first else { return false }
        return ProAccess.isProUser(profile: profile)
    }

    private var steps: [OnboardingStep] {
        OnboardingStep.allCases
    }

    var body: some View {
        ZStack {
            onboardingBackground
                .ignoresSafeArea()

            TabView(selection: $currentStep) {
                ForEach(steps, id: \.self) { step in
                    OnboardingStepView(
                        step: step
                    )
                    .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom) {
            OnboardingBottomSheet(
                step: currentStep,
                stepIndex: currentStepIndex,
                totalSteps: steps.count,
                isLastStep: currentStep == steps.last,
                selectedTheme: $selectedTheme,
                selectedGoalType: $selectedGoalType,
                goalValue: $goalValue,
                skipGoalSetup: $skipGoalSetup,
                liveActivitiesEnabled: liveActivitiesEnabled,
                isProUser: isProUser,
                showUpgradeSheet: $showUpgradeSheet,
                onPrimary: { advanceOrComplete() },
                onSkip: { completeOnboarding() },
                onNotNow: {
                    skipGoalSetup = true
                    goToNextStep()
                }
            )
        }
        .withDynamicTheme(selectedTheme)
        .onAppear {
            if let profile = profiles.first {
                selectedTheme = profile.themeColor
            }
            refreshLiveActivitiesStatus()
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }

    private var currentStepIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    private var onboardingBackground: LinearGradient {
        let top = themeColor.color.opacity(colorScheme == .dark ? 0.6 : 0.4)
        let mid = themeColor.color.opacity(colorScheme == .dark ? 0.28 : 0.16)
        let bottom = colorScheme == .dark ? Color.black : Color.white
        return LinearGradient(colors: [top, mid, bottom], startPoint: .top, endPoint: .bottom)
    }

    private func advanceOrComplete() {
        if currentStep == steps.last {
            completeOnboarding()
        } else {
            goToNextStep()
        }
    }

    private func goToNextStep() {
        guard let currentIndex = steps.firstIndex(of: currentStep) else { return }
        let nextIndex = min(currentIndex + 1, steps.count - 1)
        withAnimation(.snappy) {
            currentStep = steps[nextIndex]
        }
    }

    private func refreshLiveActivitiesStatus() {
        liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private func completeOnboarding() {
        let profile: UserProfile
        if let existingProfile = profiles.first {
            profile = existingProfile
        } else {
            let newProfile = UserProfile(hasCompletedOnboarding: true)
            modelContext.insert(newProfile)
            profile = newProfile
        }

        profile.hasCompletedOnboarding = true
        profile.themeColor = selectedTheme

        if isProUser && !skipGoalSetup {
            upsertDailyGoal(for: profile)
        }

        try? modelContext.save()

        withAnimation(.snappy) {
            isPresented = false
        }
    }

    private func upsertDailyGoal(for profile: UserProfile) {
        let endDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

        if profile.readingGoals == nil {
            profile.readingGoals = []
        }

        if let existing = profile.readingGoals?.first(where: { $0.type.isDaily }) {
            existing.type = selectedGoalType
            existing.targetValue = goalValue
            existing.startDate = Date()
            existing.endDate = endDate
            existing.isCompleted = false
            existing.currentValue = 0
            return
        }

        let newGoal = ReadingGoal(
            type: selectedGoalType,
            targetValue: goalValue,
            endDate: endDate
        )
        profile.readingGoals?.append(newGoal)
        modelContext.insert(newGoal)
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case sessions
    case habits
    case devices
    case importShare
    case goal
    case theme

    var isSetupStep: Bool {
        self == .goal || self == .theme
    }
}

private struct OnboardingStepView: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    let step: OnboardingStep

    var body: some View {
        VStack {
            Spacer(minLength: Theme.Spacing.xxl)
            OnboardingRender(
                step: step,
                colorScheme: colorScheme,
                accent: themeColor.color
            )
            .frame(maxWidth: 360)
            Spacer(minLength: Theme.Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

private struct OnboardingBottomSheet: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    let step: OnboardingStep
    let stepIndex: Int
    let totalSteps: Int
    let isLastStep: Bool
    @Binding var selectedTheme: ThemeColor
    @Binding var selectedGoalType: GoalType
    @Binding var goalValue: Int
    @Binding var skipGoalSetup: Bool
    let liveActivitiesEnabled: Bool
    let isProUser: Bool
    @Binding var showUpgradeSheet: Bool
    let onPrimary: () -> Void
    let onSkip: () -> Void
    let onNotNow: () -> Void

    private let sheetHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            onboardingHeader(title: titleKey, subtitle: subtitleKey)

            if showsDetailContent {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.md) {
                        switch step {
                        case .sessions:
                            LiveActivityCard(isEnabled: liveActivitiesEnabled)
                        case .goal:
                            goalPicker
                        case .theme:
                            themePicker
                            Text("Onboarding.Theme.ProNote")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 120)
            }

            pageDots

            Button(action: onPrimary) {
                Text(isLastStep ? "Onboarding.Button.GetStarted" : "Onboarding.Button.Continue")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(themeColor.onColor(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                            .fill(themeColor.gradient)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                                    .stroke(themeColor.color.opacity(colorScheme == .dark ? 0.35 : 0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: themeColor.color.opacity(0.35), radius: 12, y: 6)
            }

            if !step.isSetupStep {
                Button("Onboarding.Button.Skip") {
                    onSkip()
                }
                .foregroundStyle(Theme.Colors.secondaryText)
            } else if step == .goal {
                Button("Onboarding.Button.NotNow") {
                    onNotNow()
                }
                .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .frame(height: sheetHeight)
        .background(
            TopRoundedRectangle(radius: 32)
                .fill(colorScheme == .dark ? Color.black.opacity(0.92) : Color.white.opacity(0.96))
                .overlay(
                    TopRoundedRectangle(radius: 32)
                        .stroke(themeColor.color.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
                )
        )
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == stepIndex ? themeColor.color : Theme.Colors.tertiaryText.opacity(0.35))
                    .frame(width: index == stepIndex ? 18 : 6, height: 6)
                    .animation(.snappy, value: stepIndex)
            }
        }
    }

    private var showsDetailContent: Bool {
        step == .sessions || step == .goal || step == .theme
    }

    private var titleKey: LocalizedStringKey {
        switch step {
        case .welcome: return "Onboarding.Welcome.Title"
        case .sessions: return "Onboarding.Sessions.Title"
        case .habits: return "Onboarding.Habits.Title"
        case .devices: return "Onboarding.Devices.Title"
        case .importShare: return "Onboarding.Import.Title"
        case .goal: return "Onboarding.Goal.Title"
        case .theme: return "Onboarding.Theme.Title"
        }
    }

    private var subtitleKey: LocalizedStringKey {
        switch step {
        case .welcome: return "Onboarding.Welcome.Subtitle"
        case .sessions: return "Onboarding.Sessions.Subtitle"
        case .habits: return "Onboarding.Habits.Subtitle"
        case .devices: return "Onboarding.Devices.Subtitle"
        case .importShare: return "Onboarding.Import.Subtitle"
        case .goal: return "Onboarding.Goal.Subtitle"
        case .theme: return "Onboarding.Theme.Subtitle"
        }
    }

    @ViewBuilder
    private func onboardingHeader(title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Theme.Colors.text)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !isProUser {
                OnboardingCallout(
                    title: "Onboarding.Goal.ProTitle",
                    message: "Onboarding.Goal.ProMessage",
                    actionTitle: "Onboarding.Goal.Upgrade",
                    action: { showUpgradeSheet = true }
                )
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Picker("Onboarding.Goal.Type", selection: $selectedGoalType) {
                        Text(GoalType.pagesPerDay.displayNameKey).tag(GoalType.pagesPerDay)
                        Text(GoalType.minutesPerDay.displayNameKey).tag(GoalType.minutesPerDay)
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $goalValue, in: 5...180, step: selectedGoalType == .minutesPerDay ? 5 : 1) {
                        Text("\(goalValue) \(selectedGoalType.unitText(locale: locale))")
                    }
                    .font(Theme.Typography.body)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
            }
        }
    }

    private var themePicker: some View {
        let orderedColors = ThemeColorSettingsViewOrderedColors.ordered
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 12)], spacing: 12) {
            ForEach(orderedColors) { theme in
                let isFree = ThemeColorSettingsViewOrderedColors.freeColors.contains(theme)
                Button {
                    guard isFree || isProUser else {
                        showUpgradeSheet = true
                        return
                    }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTheme = theme
                    }
                } label: {
                    Circle()
                        .fill(theme.gradient)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    selectedTheme == theme ? theme.onColor(for: colorScheme) : .clear,
                                    lineWidth: 3
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
    }
}

private struct OnboardingRender: View {
    let step: OnboardingStep
    let colorScheme: ColorScheme
    let accent: Color

    var body: some View {
        if let image = UIImage(named: renderAssetName) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .shadow(color: accent.opacity(colorScheme == .dark ? 0.5 : 0.25), radius: 24, y: 14)
        } else {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 48, style: .continuous)
                        .stroke(accent.opacity(colorScheme == .dark ? 0.35 : 0.18), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "iphone")
                        .font(.system(size: 70, weight: .light))
                        .foregroundStyle(accent.opacity(colorScheme == .dark ? 0.6 : 0.4))
                )
                .frame(maxHeight: 520)
        }
    }

    private var renderAssetName: String {
        "OnboardingStep\(step.rawValue + 1)-\(colorScheme == .dark ? "Dark" : "Light")"
    }
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private struct FeaturePill: Identifiable {
    let id = UUID()
    let icon: String
    let text: LocalizedStringKey
}

private struct OnboardingHero<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1)
                )

            content
        }
        .frame(height: 220)
    }
}

private struct PlaceholderLibraryStack: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                .frame(width: 200, height: 110)
                .overlay(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.1))
                        .frame(width: 80, height: 12)
                        .padding(12)
                }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                    .frame(width: 70, height: 90)
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12))
                    .frame(width: 70, height: 90)
                RoundedRectangle(cornerRadius: 12)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                    .frame(width: 70, height: 90)
            }
        }
        .padding(24)
    }
}

private struct PlaceholderLiveActivity: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08))
                .frame(height: 70)
                .overlay {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                            .frame(width: 42, height: 54)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12))
                                .frame(width: 120, height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                                .frame(width: 90, height: 10)
                        }

                        Spacer()

                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12))
                            .frame(width: 50, height: 18)
                    }
                    .padding(16)
                }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.1))
                    .frame(width: 90, height: 36)
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.24) : Color.black.opacity(0.12))
                    .frame(width: 90, height: 36)
                RoundedRectangle(cornerRadius: 16)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.1))
                    .frame(width: 90, height: 36)
            }
        }
        .padding(20)
    }
}

private struct PlaceholderStats: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach([0.4, 0.7, 0.5, 0.9, 0.6], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12))
                        .frame(width: 20, height: 80 * value)
                }
            }
            .frame(height: 90)

            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08))
                .frame(height: 60)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                        .frame(width: 120, height: 10)
                        .padding(.leading, 16)
                }
        }
        .padding(24)
    }
}

private struct PlaceholderDevices: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08))
                .frame(width: 140, height: 170)
                .overlay(alignment: .center) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.12))
                        .frame(width: 96, height: 120)
                }

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08))
                .frame(width: 200, height: 54)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.12))
                        .frame(width: 50, height: 26)
                        .padding(.leading, 16)
                }
        }
        .padding(20)
    }
}

private struct PlaceholderImportShare: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.1))
                .frame(height: 70)
                .overlay {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                            .frame(width: 36, height: 36)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.12))
                            .frame(width: 140, height: 12)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08))
                .frame(height: 90)
                .overlay {
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.12))
                            .frame(width: 60, height: 70)
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.15))
                                .frame(width: 140, height: 12)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.12))
                                .frame(width: 100, height: 10)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
        }
        .padding(22)
    }
}

private struct PlaceholderGoal: View {
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                .frame(height: 60)
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.06))
                .frame(height: 46)
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.08))
                .frame(height: 80)
        }
        .padding(22)
    }
}

private struct PlaceholderTheme: View {
    let colorScheme: ColorScheme
    let accent: Color

    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.06))
                .frame(height: 60)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent)
                        .frame(width: 40, height: 40)
                        .padding(.leading, 16)
                }
            HStack(spacing: 12) {
                ForEach(0..<4) { _ in
                    Circle()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.black.opacity(0.08))
                        .frame(width: 34, height: 34)
                }
            }
        }
        .padding(24)
    }
}

private struct LiveActivityCard: View {
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "lock.circle.fill")
                .foregroundStyle(isEnabled ? Theme.Colors.success : Theme.Colors.secondaryText)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
            Text("Onboarding.LiveActivities.Title")
                .font(Theme.Typography.headline)
            Text(isEnabled ? "Onboarding.LiveActivities.Enabled" : "Onboarding.LiveActivities.Disabled")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer()

            if !isEnabled {
                Button("Onboarding.LiveActivities.OpenSettings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(Theme.Typography.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private struct OnboardingCallout: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(message)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)

            Button(actionTitle) {
                action()
            }
            .font(Theme.Typography.caption)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

private enum ThemeColorSettingsViewOrderedColors {
    static let freeColors: Set<ThemeColor> = [.neutral, .orange, .blue, .green]
    static let ordered: [ThemeColor] = {
        let preferred: [ThemeColor] = [.orange, .blue, .green, .neutral]
        let remaining = ThemeColor.allCases.filter { !preferred.contains($0) }
        return preferred + remaining
    }()
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

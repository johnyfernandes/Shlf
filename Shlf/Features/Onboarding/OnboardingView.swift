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
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                ForEach(steps, id: \.self) { step in
                    OnboardingStepView(
                        step: step,
                        selectedTheme: $selectedTheme,
                        selectedGoalType: $selectedGoalType,
                        goalValue: $goalValue,
                        skipGoalSetup: $skipGoalSetup,
                        liveActivitiesEnabled: liveActivitiesEnabled,
                        isProUser: isProUser,
                        showUpgradeSheet: $showUpgradeSheet
                    )
                    .tag(step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            onboardingFooter
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

    private var onboardingFooter: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button {
                advanceOrComplete()
            } label: {
                Text(currentStep == steps.last ? "Get Started" : "Continue")
                    .frame(maxWidth: .infinity)
                    .primaryButton(color: themeColor.color)
            }

            if !currentStep.isSetupStep {
                Button("Skip") {
                    completeOnboarding()
                }
                .foregroundStyle(Theme.Colors.secondaryText)
            } else if currentStep == .goal {
                Button("Not now") {
                    skipGoalSetup = true
                    goToNextStep()
                }
                .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.xl)
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
    @Binding var selectedTheme: ThemeColor
    @Binding var selectedGoalType: GoalType
    @Binding var goalValue: Int
    @Binding var skipGoalSetup: Bool
    let liveActivitiesEnabled: Bool
    let isProUser: Bool
    @Binding var showUpgradeSheet: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer(minLength: Theme.Spacing.lg)

                switch step {
                case .welcome:
                    onboardingHeader(
                        title: "Welcome to Shlf",
                        subtitle: "A calm, focused reading companion that keeps every session, streak, and goal in one place."
                    )
                    OnboardingHero {
                        PlaceholderLibraryStack(colorScheme: colorScheme)
                    }
                    onboardingPillRow([
                        FeaturePill(icon: "barcode.viewfinder", text: "Scan books"),
                        FeaturePill(icon: "doc.text.magnifyingglass", text: "Smart search"),
                        FeaturePill(icon: "list.bullet", text: "Track formats")
                    ])

                case .sessions:
                    onboardingHeader(
                        title: "Log sessions, stay in flow",
                        subtitle: "Track pages and time with Live Activities and Dynamic Island at a glance."
                    )
                    OnboardingHero {
                        PlaceholderLiveActivity(colorScheme: colorScheme)
                    }
                    LiveActivityCard(isEnabled: liveActivitiesEnabled)

                case .habits:
                    onboardingHeader(
                        title: "Build streaks and goals",
                        subtitle: "Daily goals, streaks, and trends help you stay consistent without the pressure."
                    )
                    OnboardingHero {
                        PlaceholderStats(colorScheme: colorScheme)
                    }
                    onboardingPillRow([
                        FeaturePill(icon: "flame.fill", text: "Streaks"),
                        FeaturePill(icon: "target", text: "Goals"),
                        FeaturePill(icon: "chart.bar.xaxis", text: "Trends")
                    ])

                case .devices:
                    onboardingHeader(
                        title: "Across iPhone, Watch, and iCloud",
                        subtitle: "Pick up where you left off with seamless sync and a beautiful Apple Watch companion."
                    )
                    OnboardingHero {
                        PlaceholderDevices(colorScheme: colorScheme)
                    }
                    onboardingPillRow([
                        FeaturePill(icon: "applewatch", text: "Watch"),
                        FeaturePill(icon: "icloud", text: "iCloud"),
                        FeaturePill(icon: "rectangle.and.pencil.and.ellipsis", text: "Live sync")
                    ])

                case .importShare:
                    onboardingHeader(
                        title: "Import and share instantly",
                        subtitle: "Bring your Goodreads or Kindle library and share beautiful reading cards."
                    )
                    OnboardingHero {
                        PlaceholderImportShare(colorScheme: colorScheme)
                    }
                    onboardingPillRow([
                        FeaturePill(icon: "books.vertical", text: "Goodreads"),
                        FeaturePill(icon: "book.closed", text: "Kindle"),
                        FeaturePill(icon: "square.and.arrow.up", text: "Share cards")
                    ])
                    Text("Some advanced features require Shlf Pro.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)

                case .goal:
                    onboardingHeader(
                        title: "Set a daily goal",
                        subtitle: "Pick a simple daily target. You can change this anytime in Goals."
                    )
                    OnboardingHero {
                        PlaceholderGoal(colorScheme: colorScheme)
                    }
                    goalPicker

                case .theme:
                    onboardingHeader(
                        title: "Pick your look",
                        subtitle: "Choose a theme color that matches your reading mood."
                    )
                    OnboardingHero {
                        PlaceholderTheme(colorScheme: colorScheme, accent: selectedTheme.color)
                    }
                    themePicker
                    Text("More colors and icons are available with Shlf Pro.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Spacer(minLength: Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func onboardingHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(title)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.Colors.text)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func onboardingPillRow(_ pills: [FeaturePill]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            ForEach(pills) { pill in
                HStack(spacing: 6) {
                    Image(systemName: pill.icon)
                        .font(.caption)
                    Text(pill.text)
                        .font(Theme.Typography.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06), in: Capsule())
                .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !isProUser {
                OnboardingCallout(
                    title: "Goals are part of Shlf Pro",
                    message: "Upgrade to set custom daily goals and track your progress.",
                    actionTitle: "Upgrade to Pro",
                    action: { showUpgradeSheet = true }
                )
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Picker("Goal type", selection: $selectedGoalType) {
                        Text(GoalType.pagesPerDay.displayNameKey).tag(GoalType.pagesPerDay)
                        Text(GoalType.minutesPerDay.displayNameKey).tag(GoalType.minutesPerDay)
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $goalValue, in: 5...180, step: selectedGoalType == .minutesPerDay ? 5 : 1) {
                        Text(goalValue, format: .number)
                            + Text(verbatim: " ")
                            + Text(selectedGoalType.unitTextKey)
                    }
                    .font(Theme.Typography.body)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                )
            }
        }
    }

    private var themePicker: some View {
        let orderedColors = ThemeColorSettingsViewOrderedColors.ordered
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 16)], spacing: 16) {
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
                    VStack(spacing: 8) {
                        Circle()
                            .fill(theme.gradient)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        selectedTheme == theme ? theme.onColor(for: colorScheme) : .clear,
                                        lineWidth: 3
                                    )
                            )
                        Text(theme.displayNameKey)
                            .font(.caption)
                            .foregroundStyle(selectedTheme == theme ? theme.color : Theme.Colors.secondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
    }
}

private struct FeaturePill: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
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
                Text("Live Activities")
                    .font(Theme.Typography.headline)
                Text(isEnabled ? "Enabled on your Lock Screen." : "Enable Live Activities in Settings.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer()

            if !isEnabled {
                Button("Open Settings") {
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
    let title: String
    let message: String
    let actionTitle: String
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

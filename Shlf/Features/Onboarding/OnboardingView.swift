//
//  OnboardingView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Binding var isPresented: Bool

    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "books.vertical.fill",
            title: "Track Your Reading",
            description: "Add books from your physical library, ebooks, or audiobooks. Scan barcodes or search our database."
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Build Your Habit",
            description: "Log reading sessions, track pages and time, and build reading streaks to stay motivated."
        ),
        OnboardingPage(
            icon: "star.fill",
            title: "Level Up",
            description: "Earn XP for every page you read, unlock achievements, and level up your reading game."
        ),
        OnboardingPage(
            icon: "cloud.fill",
            title: "Sync Everywhere",
            description: "Your library syncs across all your devices with iCloud, so you can pick up where you left off."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .frame(maxWidth: .infinity)
                        .primaryButton()
                }

                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }

    private func completeOnboarding() {
        // Get or create profile and mark onboarding as complete
        if let existingProfile = profiles.first {
            existingProfile.hasCompletedOnboarding = true
        } else {
            let profile = UserProfile(hasCompletedOnboarding: true)
            modelContext.insert(profile)
        }

        // Save context
        try? modelContext.save()

        withAnimation {
            isPresented = false
        }
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 100))
                .foregroundStyle(Theme.Colors.primary.gradient)
                .symbolEffect(.bounce, value: page.icon)

            VStack(spacing: Theme.Spacing.md) {
                Text(page.title)
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(Theme.Colors.text)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }

            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

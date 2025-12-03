//
//  LevelDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct LevelDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Large progress ring
                    VStack(spacing: Theme.Spacing.lg) {
                        ProgressRing(
                            progress: profile.xpProgressPercentage / 100,
                            lineWidth: 12,
                            gradient: Theme.Colors.xpGradient,
                            size: 160
                        )
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(Theme.Colors.xpGradient)

                                Text("\(Int(profile.xpProgressPercentage))%")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.text)
                            }
                        }

                        VStack(spacing: Theme.Spacing.xs) {
                            Text("Level \(profile.currentLevel)")
                                .font(Theme.Typography.title)
                                .foregroundStyle(Theme.Colors.text)

                            HStack(spacing: Theme.Spacing.xs) {
                                Text("\(profile.totalXP)")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.text)

                                Text("/ \(profile.xpForNextLevel) XP")
                                    .font(Theme.Typography.callout)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                        }
                    }

                    // XP breakdown
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Progress")
                            .sectionHeader()

                        VStack(spacing: Theme.Spacing.sm) {
                            HStack {
                                Text("Current Level")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.secondaryText)

                                Spacer()

                                Text("Level \(profile.currentLevel)")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.text)
                            }

                            HStack {
                                Text("Total XP")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.secondaryText)

                                Spacer()

                                Text("\(profile.totalXP) XP")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.text)
                            }

                            HStack {
                                Text("XP to Next Level")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.secondaryText)

                                Spacer()

                                Text("\(profile.xpForNextLevel - profile.totalXP) XP")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(themeColor.color)
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .cardStyle()
                    }

                    // How to earn XP
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("Earn XP By")
                            .sectionHeader()

                        VStack(spacing: Theme.Spacing.sm) {
                            XPSourceRow(
                                icon: "book.pages.fill",
                                title: "Reading Pages",
                                description: "1 XP per page read",
                                gradient: Theme.Colors.xpGradient
                            )

                            XPSourceRow(
                                icon: "checkmark.circle.fill",
                                title: "Finishing Books",
                                description: "50 XP bonus",
                                gradient: Theme.Colors.successGradient
                            )

                            XPSourceRow(
                                icon: "flame.fill",
                                title: "Daily Streaks",
                                description: "10 XP per day",
                                gradient: Theme.Colors.streakGradient
                            )
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Your Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct XPSourceRow: View {
    let icon: String
    let title: String
    let description: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(gradient)
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .cardStyle()
    }
}

#Preview {
    LevelDetailView(profile: UserProfile())
}

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

    private var xpPerPageSubtitle: String {
        "Earn \(XPCalculator.xpPerPage) XP per page"
    }

    private var xpPerPageDetail: String {
        "\(XPCalculator.xpPerPage) XP per page read"
    }

    private var durationBonusDetail: String {
        let bonusValues = XPCalculator.durationBonuses.map { "\($0.bonus)" }.joined(separator: "/")
        let timeValues = XPCalculator.durationBonuses.map { formatMinutes($0.minMinutes) }.joined(separator: "/")
        return "\(bonusValues) XP at \(timeValues)"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Dynamic gradient background
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.12),
                        themeColor.color.opacity(0.04),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Progress Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Your Progress")
                                    .font(.headline)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                // Progress Ring
                                HStack {
                                    Spacer()

                                    ProgressRing(
                                        progress: profile.xpProgressPercentage / 100,
                                        lineWidth: 12,
                                        gradient: LinearGradient(
                                            colors: [
                                                themeColor.color,
                                                themeColor.color.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        size: 140
                                    )
                                    .overlay {
                                        VStack(spacing: 4) {
                                            ZStack {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundStyle(themeColor.color)
                                                    .blur(radius: 8)
                                                    .opacity(0.6)

                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 28))
                                                    .foregroundStyle(
                                                        LinearGradient(
                                                            colors: [
                                                                themeColor.color,
                                                                themeColor.color.opacity(0.8)
                                                            ],
                                                            startPoint: .top,
                                                            endPoint: .bottom
                                                        )
                                                    )
                                            }

                                            (
                                                Text(Int(profile.xpProgressPercentage), format: .number)
                                                + Text(verbatim: "%")
                                            )
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .foregroundStyle(Theme.Colors.text)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)

                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .foregroundStyle(themeColor.color)

                                    Text(
                                        String.localizedStringWithFormat(
                                            String(localized: "Level %lld"),
                                            profile.currentLevel
                                        )
                                    )
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Spacer()

                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(themeColor.color)

                                    Text(
                                        String.localizedStringWithFormat(
                                            String(localized: "%lld XP"),
                                            profile.totalXP
                                        )
                                    )
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                            }
                            .padding(12)
                            .background(themeColor.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // XP Breakdown Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("XP Breakdown")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        themeColor.color,
                                                        themeColor.color.opacity(0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "star.fill")
                                            .font(.system(size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: themeColor.color.opacity(0.3), radius: 6, y: 3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Current Level")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text(
                                            String.localizedStringWithFormat(
                                                String(localized: "Level %lld"),
                                                profile.currentLevel
                                            )
                                        )
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                            Text(
                                                String.localizedStringWithFormat(
                                                    String(localized: "%lld total XP"),
                                                    profile.totalXP
                                                )
                                            )
                                                .font(.caption)
                                        }
                                        .foregroundStyle(themeColor.color)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        themeColor.color,
                                                        themeColor.color.opacity(0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "arrow.up.forward")
                                            .font(.system(size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: themeColor.color.opacity(0.3), radius: 6, y: 3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Next Level")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text(
                                            String.localizedStringWithFormat(
                                                String(localized: "Level %lld"),
                                                profile.currentLevel + 1
                                            )
                                        )
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                            Text(
                                                String.localizedStringWithFormat(
                                                    String(localized: "%lld XP needed"),
                                                    profile.xpForNextLevel - profile.totalXP
                                                )
                                            )
                                                .font(.caption)
                                        }
                                        .foregroundStyle(themeColor.color)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // How to Earn XP Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Earn XP By")
                                    .font(.headline)
                            }

                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        themeColor.color,
                                                        themeColor.color.opacity(0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "book.pages.fill")
                                            .font(.system(size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: themeColor.color.opacity(0.3), radius: 6, y: 3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Reading Pages")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text(xpPerPageSubtitle)
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "book.pages")
                                                .font(.caption2)
                                            Text(xpPerPageDetail)
                                                .font(.caption)
                                        }
                                        .foregroundStyle(themeColor.color)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        themeColor.color,
                                                        themeColor.color.opacity(0.7)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 18))
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: themeColor.color.opacity(0.3), radius: 6, y: 3)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Session Bonus")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text("Read longer sessions")
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                        Text(durationBonusDetail)
                                            .font(.caption)
                                        }
                                        .foregroundStyle(themeColor.color)
                                    }

                                    Spacer()
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Your Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
        }
    }
}

private func formatMinutes(_ minutes: Int) -> String {
    guard minutes > 0 else { return "0m" }
    if minutes % 60 == 0 {
        return "\(minutes / 60)h"
    }
    return "\(minutes)m"
}

#Preview {
    LevelDetailView(profile: UserProfile())
}

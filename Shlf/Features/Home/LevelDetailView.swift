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
    @Environment(\.locale) private var locale
    @Bindable var profile: UserProfile

    private var xpPerPageSubtitle: String {
        let format = localized("Level.XPPerPage.Subtitle %lld", locale: locale)
        return String(format: format, locale: locale, arguments: [XPCalculator.xpPerPage])
    }

    private var xpPerPageDetail: String {
        let format = localized("Level.XPPerPage.Detail %lld", locale: locale)
        return String(format: format, locale: locale, arguments: [XPCalculator.xpPerPage])
    }

    private var durationBonusDetail: String {
        let bonusValues = XPCalculator.durationBonuses.map { "\($0.bonus)" }.joined(separator: "/")
        let timeValues = XPCalculator.durationBonuses.map { formatMinutes($0.minMinutes) }.joined(separator: "/")
        let format = localized("Level.DurationBonus.Detail %@ %@", locale: locale)
        return String(format: format, locale: locale, arguments: [bonusValues, timeValues])
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

                                Text(verbatim: localized("Level.Progress.Title", locale: locale))
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

                                            Text("\(Int(profile.xpProgressPercentage))%")
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
                                        String(
                                            format: localized("Level.LevelFormat %lld", locale: locale),
                                            locale: locale,
                                            arguments: [profile.currentLevel]
                                        )
                                    )
                                        .font(.title2)
                                        .fontWeight(.bold)

                                    Spacer()

                                    Image(systemName: "bolt.fill")
                                        .foregroundStyle(themeColor.color)

                                    Text(
                                        String(
                                            format: localized("Level.XPFormat %lld", locale: locale),
                                            locale: locale,
                                            arguments: [profile.totalXP]
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

                                Text(verbatim: localized("Level.Breakdown.Title", locale: locale))
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
                                        Text(verbatim: localized("Level.CurrentLevel", locale: locale))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text(
                                            String(
                                                format: localized("Level.LevelFormat %lld", locale: locale),
                                                locale: locale,
                                                arguments: [profile.currentLevel]
                                            )
                                        )
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                            Text(
                                                String(
                                                    format: localized("Level.TotalXPFormat %lld", locale: locale),
                                                    locale: locale,
                                                    arguments: [profile.totalXP]
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
                                        Text(verbatim: localized("Level.NextLevel", locale: locale))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text(
                                            String(
                                                format: localized("Level.LevelFormat %lld", locale: locale),
                                                locale: locale,
                                                arguments: [profile.currentLevel + 1]
                                            )
                                        )
                                            .font(.caption)
                                            .foregroundStyle(Theme.Colors.secondaryText)
                                            .lineLimit(1)

                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption2)
                                            Text(
                                                String(
                                                    format: localized("Level.XPNeededFormat %lld", locale: locale),
                                                    locale: locale,
                                                    arguments: [profile.xpForNextLevel - profile.totalXP]
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

                                Text(verbatim: localized("Level.EarnXPBy", locale: locale))
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
                                        Text(verbatim: localized("Level.ReadingPages", locale: locale))
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
                                        Text(verbatim: localized("Level.SessionBonus", locale: locale))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Theme.Colors.text)
                                            .lineLimit(2)

                                        Text(verbatim: localized("Level.SessionBonus.Subtitle", locale: locale))
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
            .navigationTitle("Level.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(verbatim: localized("Common.Done", locale: locale))
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

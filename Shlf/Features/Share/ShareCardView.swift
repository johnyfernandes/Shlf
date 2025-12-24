//
//  ShareCardView.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI

struct ShareCardView: View {
    let content: ShareCardContent
    let style: ShareCardStyle

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let scale = min(size.width / 390, size.height / 844)
            let horizontalPadding = 32 * scale
            let verticalSpacing = 18 * scale
            let isLightBackground = style.background == .paper
            let primaryText = isLightBackground ? Color.black.opacity(0.88) : Color.white
            let secondaryText = isLightBackground ? Color.black.opacity(0.65) : Color.white.opacity(0.85)
            let tertiaryText = isLightBackground ? Color.black.opacity(0.45) : Color.white.opacity(0.7)
            let statFill = isLightBackground ? Color.white.opacity(0.7) : Color.white.opacity(0.12)
            let statStroke = isLightBackground ? Color.black.opacity(0.08) : Color.white.opacity(0.15)
            let shadowColor = isLightBackground ? Color.black.opacity(0.12) : Color.black.opacity(0.25)

            ZStack {
                ShareBackgroundView(style: style.background, accentColor: style.accentColor)

                VStack(alignment: .leading, spacing: verticalSpacing) {
                    ShareHeaderView(
                        badge: content.badge,
                        accentColor: style.accentColor,
                        textColor: primaryText,
                        badgeFill: style.accentColor.opacity(isLightBackground ? 0.18 : 0.25),
                        badgeStroke: isLightBackground ? Color.black.opacity(0.1) : Color.white.opacity(0.2),
                        scale: scale
                    )

                    VStack(alignment: .leading, spacing: 8 * scale) {
                        Text(content.title)
                            .font(.system(size: 34 * scale, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryText)
                            .lineLimit(3)

                        if let subtitle = content.subtitle {
                            Text(subtitle)
                                .font(.system(size: 18 * scale, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryText)
                                .lineLimit(2)
                        }

                        if let period = content.period {
                            Text(period)
                                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(tertiaryText)
                        }
                    }

                    ShareHeroView(
                        coverImage: content.coverImage,
                        progress: content.progress,
                        progressText: content.progressText,
                        accentColor: style.accentColor,
                        primaryText: primaryText,
                        shadowColor: shadowColor,
                        scale: scale
                    )

                    ShareStatsGrid(
                        stats: content.stats,
                        primaryText: primaryText,
                        secondaryText: tertiaryText,
                        fillColor: statFill,
                        strokeColor: statStroke,
                        scale: scale
                    )

                    Spacer(minLength: 12 * scale)

                    Text(content.footer)
                        .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(tertiaryText)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 28 * scale)
            }
        }
    }
}

private struct ShareHeaderView: View {
    let badge: String?
    let accentColor: Color
    let textColor: Color
    let badgeFill: Color
    let badgeStroke: Color
    let scale: CGFloat

    var body: some View {
        HStack(spacing: 12 * scale) {
            Label("Shlf", systemImage: "books.vertical.fill")
                .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)

            Spacer(minLength: 0)

            if let badge {
                Text(badge)
                    .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 12 * scale)
                    .padding(.vertical, 6 * scale)
                    .background(
                        Capsule()
                            .fill(badgeFill)
                    )
                    .overlay(
                        Capsule()
                            .stroke(badgeStroke, lineWidth: 1)
                    )
            }
        }
    }
}

private struct ShareHeroView: View {
    let coverImage: UIImage?
    let progress: Double?
    let progressText: String?
    let accentColor: Color
    let primaryText: Color
    let shadowColor: Color
    let scale: CGFloat

    var body: some View {
        if coverImage != nil || progress != nil {
            HStack(alignment: .top, spacing: 16 * scale) {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140 * scale, height: 200 * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: shadowColor, radius: 16 * scale, y: 8 * scale)
                }

                if let progress {
                    VStack(alignment: .leading, spacing: 10 * scale) {
                        ShareProgressRing(
                            progress: progress,
                            color: accentColor,
                            trackColor: primaryText.opacity(0.2),
                            size: 76 * scale,
                            lineWidth: 10 * scale
                        )

                        if let progressText {
                            Text(progressText)
                                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryText.opacity(0.85))
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct ShareStatsGrid: View {
    let stats: [ShareStatItem]
    let primaryText: Color
    let secondaryText: Color
    let fillColor: Color
    let strokeColor: Color
    let scale: CGFloat

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16 * scale),
            GridItem(.flexible(), spacing: 16 * scale)
        ]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16 * scale) {
            ForEach(stats.prefix(4)) { stat in
                ShareStatView(
                    stat: stat,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    fillColor: fillColor,
                    strokeColor: strokeColor,
                    scale: scale
                )
            }
        }
    }
}

private struct ShareStatView: View {
    let stat: ShareStatItem
    let primaryText: Color
    let secondaryText: Color
    let fillColor: Color
    let strokeColor: Color
    let scale: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 10 * scale) {
            Image(systemName: stat.icon)
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundStyle(secondaryText)
                .frame(width: 20 * scale, height: 20 * scale)

            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(stat.value)
                    .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)

                Text(stat.label)
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6 * scale)
        .padding(.horizontal, 8 * scale)
        .background(
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

private struct ShareProgressRing: View {
    let progress: Double
    let color: Color
    let trackColor: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

private struct ShareBackgroundView: View {
    let style: ShareBackgroundStyle
    let accentColor: Color

    var body: some View {
        ZStack {
            switch style {
            case .aurora:
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.12, blue: 0.35),
                        Color(red: 0.1, green: 0.4, blue: 0.55),
                        Color(red: 0.12, green: 0.55, blue: 0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .sunrise:
                LinearGradient(
                    colors: [
                        Color(red: 0.93, green: 0.4, blue: 0.35),
                        Color(red: 0.96, green: 0.65, blue: 0.35),
                        Color(red: 0.98, green: 0.8, blue: 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .paper:
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95),
                        Color(red: 0.94, green: 0.92, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            Circle()
                .fill(accentColor.opacity(style == .paper ? 0.15 : 0.35))
                .blur(radius: 120)
                .offset(x: -180, y: -220)

            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .fill(Color.white.opacity(style == .paper ? 0.2 : 0.1))
                .blur(radius: 80)
                .offset(x: 160, y: 120)

            if style == .paper {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    .blendMode(.overlay)
            }
        }
    }
}

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
            let isCentered = style.layout == .centered
            let primaryText = isLightBackground ? Color.black.opacity(0.88) : Color.white
            let secondaryText = isLightBackground ? Color.black.opacity(0.65) : Color.white.opacity(0.85)
            let tertiaryText = isLightBackground ? Color.black.opacity(0.45) : Color.white.opacity(0.7)
            let statFill = isLightBackground ? Color.white.opacity(0.7) : Color.white.opacity(0.12)
            let statStroke = isLightBackground ? Color.black.opacity(0.08) : Color.white.opacity(0.15)
            let shadowColor = isLightBackground ? Color.black.opacity(0.12) : Color.black.opacity(0.25)
            let ringBackground = isLightBackground ? Color.white.opacity(0.45) : Color.black.opacity(0.25)

            ZStack {
                ShareBackgroundView(style: style.background, accentColor: style.accentColor)

                VStack(alignment: isCentered ? .center : .leading, spacing: verticalSpacing) {
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
                            .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
                            .multilineTextAlignment(isCentered ? .center : .leading)

                        if let subtitle = content.subtitle {
                            Text(subtitle)
                                .font(.system(size: 18 * scale, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryText)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
                                .multilineTextAlignment(isCentered ? .center : .leading)
                        }

                        if let period = content.period {
                            Text(period)
                                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(tertiaryText)
                                .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
                        }
                    }

                    ForEach(content.blocks) { block in
                        blockView(
                            block,
                            primaryText: primaryText,
                            secondaryText: tertiaryText,
                        statFill: statFill,
                        statStroke: statStroke,
                        shadowColor: shadowColor,
                        ringBackground: ringBackground,
                        isCentered: isCentered,
                        scale: scale
                    )
                    }

                    Spacer(minLength: 12 * scale)

                    Text(content.footer)
                        .font(.system(size: 13 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(tertiaryText)
                        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
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
    let showProgressRing: Bool
    let hideProgressRingWhenComplete: Bool
    let accentColor: Color
    let primaryText: Color
    let shadowColor: Color
    let ringBackground: Color
    let isCentered: Bool
    let scale: CGFloat

    var body: some View {
        if coverImage != nil || progress != nil {
            if let coverImage {
                let shouldShowRing = shouldShowRing(for: progress)

                let heroContent = HStack(alignment: .top, spacing: 16 * scale) {
                    ZStack(alignment: .bottomTrailing) {
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

                        if let progress, shouldShowRing {
                            ShareProgressRing(
                                progress: progress,
                                color: accentColor,
                                trackColor: primaryText.opacity(0.2),
                                size: 44 * scale,
                                lineWidth: 6 * scale
                            )
                            .padding(5 * scale)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.7)
                                    .overlay(
                                        Circle()
                                            .fill(ringBackground)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(primaryText.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .shadow(color: shadowColor.opacity(0.4), radius: 6 * scale, y: 3 * scale)
                            .padding(6 * scale)
                        }
                    }

                    if let progressText {
                        VStack(alignment: .leading, spacing: 6 * scale) {
                            Text("Progress")
                                .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryText.opacity(0.6))

                            if let progress {
                                Text("\(Int((progress * 100).rounded()))%")
                                    .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                                    .foregroundStyle(primaryText)
                            }

                            Text(progressText)
                                .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryText.opacity(0.85))
                        }
                        .padding(.top, 6 * scale)
                    }
                }

                if isCentered {
                    HStack {
                        Spacer(minLength: 0)
                        heroContent
                        Spacer(minLength: 0)
                    }
                } else {
                    heroContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let progress {
                let shouldShowRing = shouldShowRing(for: progress)
                VStack(spacing: 10 * scale) {
                    if shouldShowRing {
                        ShareProgressRing(
                            progress: progress,
                            color: accentColor,
                            trackColor: primaryText.opacity(0.2),
                            size: 76 * scale,
                            lineWidth: 10 * scale
                        )
                        .padding(8 * scale)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.7)
                                .overlay(
                                    Circle()
                                        .fill(ringBackground)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(primaryText.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .shadow(color: shadowColor.opacity(0.35), radius: 10 * scale, y: 6 * scale)
                    }

                    if let progressText {
                        Text(progressText)
                            .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryText.opacity(0.85))
                            .multilineTextAlignment(isCentered ? .center : .leading)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func shouldShowRing(for progress: Double?) -> Bool {
        guard showProgressRing, let progress else { return false }
        guard hideProgressRingWhenComplete else { return true }
        return progress > 0 && progress < 1
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
        .frame(maxWidth: .infinity)
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

private struct ShareQuoteView: View {
    let quote: ShareQuote
    let accentColor: Color
    let primaryText: Color
    let secondaryText: Color
    let fillColor: Color
    let strokeColor: Color
    let isCentered: Bool
    let scale: CGFloat

    var body: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 6 * scale) {
            Text("“\(quote.text)”")
                .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(primaryText)
                .lineLimit(3)
                .multilineTextAlignment(isCentered ? .center : .leading)

            if let attribution = quote.attribution {
                Text(attribution)
                    .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
        .padding(.vertical, 10 * scale)
        .padding(.horizontal, 12 * scale)
        .background(
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

private struct ShareGraphView: View {
    let graph: ShareGraph
    let accentColor: Color
    let primaryText: Color
    let secondaryText: Color
    let fillColor: Color
    let strokeColor: Color
    let isCentered: Bool
    let scale: CGFloat

    private var normalizedValues: [Double] {
        let maxValue = graph.values.max() ?? 0
        guard maxValue > 0 else {
            return graph.values.map { _ in 0 }
        }
        return graph.values.map { min(max($0 / maxValue, 0), 1) }
    }

    var body: some View {
        VStack(alignment: isCentered ? .center : .leading, spacing: 8 * scale) {
            Text(graph.title)
                .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryText)
                .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)

            if let subtitle = graph.subtitle {
                Text(subtitle)
                    .font(.system(size: 12 * scale, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryText)
                    .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
            }

            GeometryReader { proxy in
                let size = proxy.size

                ZStack {
                    switch graph.style {
                    case .line:
                        let points = normalizedValues.enumerated().map { index, value -> CGPoint in
                            let x = size.width * CGFloat(index) / CGFloat(max(normalizedValues.count - 1, 1))
                            let y = size.height * (1 - CGFloat(value))
                            return CGPoint(x: x, y: y)
                        }

                        if points.count > 1 {
                            Path { path in
                                path.move(to: points[0])
                                for point in points.dropFirst() {
                                    path.addLine(to: point)
                                }
                            }
                            .stroke(accentColor, style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round, lineJoin: .round))

                            Path { path in
                                path.move(to: CGPoint(x: points[0].x, y: size.height))
                                path.addLine(to: points[0])
                                for point in points.dropFirst() {
                                    path.addLine(to: point)
                                }
                                path.addLine(to: CGPoint(x: points.last?.x ?? 0, y: size.height))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(0.35), accentColor.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            if let last = points.last {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 8 * scale, height: 8 * scale)
                                    .position(last)
                            }
                        } else {
                            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                                .fill(accentColor.opacity(0.12))
                        }
                    case .bars:
                        let values = normalizedValues
                        let count = max(values.count, 1)
                        let spacing = 6 * scale
                        let totalSpacing = spacing * CGFloat(max(count - 1, 0))
                        let barWidth = max(2 * scale, (size.width - totalSpacing) / CGFloat(count))

                        HStack(alignment: .bottom, spacing: spacing) {
                            ForEach(values.indices, id: \.self) { index in
                                let value = values[index]
                                RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [accentColor.opacity(0.9), accentColor.opacity(0.45)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: max(2 * scale, size.height * CGFloat(value)))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
            }
            .frame(height: 90 * scale)
            .padding(.top, 4 * scale)
        }
        .padding(.vertical, 10 * scale)
        .padding(.horizontal, 12 * scale)
        .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
        .background(
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
    }
}

private extension ShareCardView {
    @ViewBuilder
    func blockView(
        _ block: ShareContentBlock,
        primaryText: Color,
        secondaryText: Color,
        statFill: Color,
        statStroke: Color,
        shadowColor: Color,
        ringBackground: Color,
        isCentered: Bool,
        scale: CGFloat
    ) -> some View {
        switch block {
        case .hero:
                    ShareHeroView(
                        coverImage: content.coverImage,
                        progress: content.progress,
                        progressText: content.progressText,
                        showProgressRing: content.showProgressRing,
                        hideProgressRingWhenComplete: content.hideProgressRingWhenComplete,
                        accentColor: style.accentColor,
                        primaryText: primaryText,
                        shadowColor: shadowColor,
                        ringBackground: ringBackground,
                        isCentered: isCentered,
                        scale: scale
                    )
        case .quote:
            if let quote = content.quote {
                ShareQuoteView(
                    quote: quote,
                    accentColor: style.accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    fillColor: statFill,
                    strokeColor: statStroke,
                    isCentered: isCentered,
                    scale: scale
                )
            }
        case .graph:
            if let graph = content.graph {
                ShareGraphView(
                    graph: graph,
                    accentColor: style.accentColor,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    fillColor: statFill,
                    strokeColor: statStroke,
                    isCentered: isCentered,
                    scale: scale
                )
            }
        case .stats:
            if !content.stats.isEmpty {
                ShareStatsGrid(
                    stats: content.stats,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                    fillColor: statFill,
                    strokeColor: statStroke,
                    scale: scale
                )
                .frame(maxWidth: .infinity, alignment: isCentered ? .center : .leading)
            }
        }
    }
}

private struct ShareBackgroundView: View {
    let style: ShareBackgroundStyle
    let accentColor: Color

    var body: some View {
        ZStack {
            switch style {
            case .paper:
                LinearGradient(
                    colors: [
                        Color(red: 0.98, green: 0.97, blue: 0.95),
                        Color(red: 0.94, green: 0.92, blue: 0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .paperDark:
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.11, blue: 0.1),
                        Color(red: 0.2, green: 0.18, blue: 0.16)
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

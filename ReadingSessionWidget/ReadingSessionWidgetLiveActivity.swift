//
//  ReadingSessionWidgetLiveActivity.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents
#if canImport(UIKit)
import UIKit
#endif

struct ReadingSessionWidgetAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        // Dynamic stateful properties about your activity go here!
        var currentPage: Int
        var pagesRead: Int
        var xpEarned: Int
        var isPaused: Bool
        var timerStartTime: Date
        var pausedElapsedSeconds: Int?
    }

    // Fixed non-changing properties about your activity go here!
    var bookTitle: String
    var bookAuthor: String
    var totalPages: Int
    var startPage: Int
    var startTime: Date
    var themeColorHex: String // Store as hex string for Codable compliance
    var coverImageURLString: String?
    var compactCoverURLString: String?

    var themeColor: Color {
        Color(hex: themeColorHex) ?? .cyan
    }

    var coverImageURL: URL? {
        guard let coverImageURLString else { return nil }
        return URL(string: coverImageURLString)
    }

    var compactCoverURL: URL? {
        guard let compactCoverURLString else { return nil }
        return URL(string: compactCoverURLString)
    }
}

struct ReadingSessionWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            ReadingSessionLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    let timerWidth: CGFloat = 86
                    let topOffset: CGFloat = -6

                    HStack(alignment: .top, spacing: 10) {
                        liveActivityCover(
                            context: context,
                            size: CGSize(width: 38, height: 52),
                            cornerRadius: 6
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.bookTitle)
                                .font(.headline.weight(.semibold))
                                .lineLimit(1)

                            Text(context.attributes.bookAuthor)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(
                                String.localizedStringWithFormat(
                                    String(localized: "%lld/%lld pages"),
                                    context.state.currentPage,
                                    context.attributes.totalPages
                                )
                            )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        ZStack(alignment: .topTrailing) {
                            if context.state.isPaused {
                                Text("Paused")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                                    .offset(y: -12)
                                    .padding(.trailing, 6)
                            }

                            ZStack(alignment: .trailing) {
                                Text("99:59:59")
                                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .hidden()

                                if context.state.isPaused,
                                   let pausedElapsed = context.state.pausedElapsedSeconds {
                                    Text(formattedElapsed(seconds: pausedElapsed))
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                } else {
                                    LiveActivityTimerView(startTime: context.state.timerStartTime)
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                }
                            }
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        }
                        .frame(width: timerWidth, alignment: .trailing)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(y: topOffset)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        liveActivityButton(
                            title: "1",
                            systemImage: "minus",
                            tint: context.attributes.themeColor.opacity(0.25),
                            intent: DecrementPageIntent()
                        )

                        liveActivityButton(
                            title: context.state.isPaused ? "Resume" : "Pause",
                            systemImage: context.state.isPaused ? "play.fill" : "pause.fill",
                            tint: context.attributes.themeColor.opacity(0.25),
                            intent: TogglePauseIntent()
                        )

                        liveActivityButton(
                            title: "1",
                            systemImage: "plus",
                            tint: context.attributes.themeColor.opacity(0.25),
                            intent: IncrementPageIntent()
                        )
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                compactLeadingCover(context: context)
            } compactTrailing: {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "%lld/%lld"),
                        context.state.currentPage,
                        context.attributes.totalPages
                    )
                )
                    .foregroundStyle(.white)
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "book.fill")
            }
            .keylineTint(context.attributes.themeColor)
        }
    }
}

// MARK: - Lock Screen View

struct ReadingSessionLockScreenView: View {
    let context: ActivityViewContext<ReadingSessionWidgetAttributes>

    var body: some View {
        let accent = context.attributes.themeColor

        VStack(spacing: 10) {
            HStack(spacing: 12) {
                coverView

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.bookTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Text(context.attributes.bookAuthor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%lld/%lld pages"),
                            context.state.currentPage,
                            context.attributes.totalPages
                        )
                    )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if context.state.isPaused {
                        Text("Paused")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    if context.state.isPaused,
                       let pausedElapsed = context.state.pausedElapsedSeconds {
                        Text(formattedElapsed(seconds: pausedElapsed))
                            .font(.headline)
                            .monospacedDigit()
                    } else {
                        LiveActivityTimerView(startTime: context.state.timerStartTime)
                            .font(.headline)
                            .monospacedDigit()
                    }

                }
                .frame(width: 72, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                liveActionButton(
                    title: "1",
                    systemImage: "minus",
                    tint: accent.opacity(0.2),
                    intent: DecrementPageIntent()
                )

                liveActionButton(
                    title: context.state.isPaused ? "Resume" : "Pause",
                    systemImage: context.state.isPaused ? "play.fill" : "pause.fill",
                    tint: accent.opacity(0.2),
                    intent: TogglePauseIntent()
                )

                liveActionButton(
                    title: "1",
                    systemImage: "plus",
                    tint: accent.opacity(0.2),
                    intent: IncrementPageIntent()
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(0.18),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .activityBackgroundTint(.clear)
        .activitySystemActionForegroundColor(accent)
    }

    private var coverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(context.attributes.themeColor.opacity(0.2))

            if let fileImage = localCoverImage() {
                fileImage
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else if let url = context.attributes.coverImageURL {
                AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(context.attributes.themeColor.opacity(0.12))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(width: 44, height: 58)
    }

    private func localCoverImage() -> Image? {
#if canImport(UIKit)
        guard let url = context.attributes.coverImageURL, url.isFileURL else { return nil }
        if let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
#endif
        return nil
    }

    private func liveActionButton<IntentType: AppIntent>(
        title: String,
        systemImage: String,
        tint: Color,
        intent: IntentType
    ) -> some View {
        Button(intent: intent) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(tint.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dynamic Island Helpers

private func liveActivityCover(
    context: ActivityViewContext<ReadingSessionWidgetAttributes>,
    size: CGSize,
    cornerRadius: CGFloat
) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(context.attributes.themeColor.opacity(0.2))

        if let fileImage = localCoverImage(context: context) {
            fileImage
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else if let url = context.attributes.coverImageURL {
            AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(context.attributes.themeColor.opacity(0.12))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
    .frame(width: size.width, height: size.height)
}

private func localCoverImage(
    context: ActivityViewContext<ReadingSessionWidgetAttributes>
) -> Image? {
#if canImport(UIKit)
    guard let url = (context.attributes.compactCoverURL ?? context.attributes.coverImageURL),
          url.isFileURL else { return nil }
    if let image = UIImage(contentsOfFile: url.path) {
        return Image(uiImage: image)
    }
#endif
    return nil
}

private func compactLeadingCover(
    context: ActivityViewContext<ReadingSessionWidgetAttributes>
) -> some View {
    let coverSize = CGSize(width: 13, height: 18)

    return ZStack {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.black.opacity(0.35))

        if let image = localCoverImage(context: context) {
            image
                .resizable()
                .scaledToFit()
                .frame(width: coverSize.width, height: coverSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else if let url = context.attributes.coverImageURL {
            AsyncImage(url: url, transaction: Transaction(animation: nil)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                default:
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: coverSize.width, height: coverSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    .frame(width: 18, height: 18)
    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
}

private func liveActivityButton<IntentType: AppIntent>(
    title: String,
    systemImage: String,
    tint: Color,
    intent: IntentType
) -> some View {
    Button(intent: intent) {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))

            Text(title)
                .font(.callout.weight(.semibold))
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(tint.opacity(0.6), lineWidth: 1)
                )
        )
    }
    .buttonStyle(.plain)
}

private func formattedElapsed(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainingSeconds = seconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    return String(format: "%02d:%02d", minutes, remainingSeconds)
}

private struct LiveActivityTimerView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    let startTime: Date

    var body: some View {
        if isLuminanceReduced {
            Text(
                timerInterval: startTime...Date.distantFuture,
                countsDown: false
            )
        } else {
            Text(startTime, style: .timer)
        }
    }
}

// MARK: - Previews

extension ReadingSessionWidgetAttributes {
    fileprivate static var preview: ReadingSessionWidgetAttributes {
        ReadingSessionWidgetAttributes(
            bookTitle: "The 48 Laws of Power",
            bookAuthor: "Robert Greene",
            totalPages: 463,
            startPage: 0,
            startTime: Date().addingTimeInterval(-600), // 10 minutes ago
            themeColorHex: "#00CED1",
            coverImageURLString: "https://covers.openlibrary.org/b/isbn/0140280197-L.jpg",
            compactCoverURLString: nil
        )
    }
}

// MARK: - Color Hex Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

extension ReadingSessionWidgetAttributes.ContentState {
    fileprivate static var starting: ReadingSessionWidgetAttributes.ContentState {
        ReadingSessionWidgetAttributes.ContentState(
            currentPage: 5,
            pagesRead: 5,
            xpEarned: 15,
            isPaused: false,
            timerStartTime: Date().addingTimeInterval(-300),
            pausedElapsedSeconds: nil
        )
    }

    fileprivate static var reading: ReadingSessionWidgetAttributes.ContentState {
        ReadingSessionWidgetAttributes.ContentState(
            currentPage: 25,
            pagesRead: 25,
            xpEarned: 75,
            isPaused: false,
            timerStartTime: Date().addingTimeInterval(-900),
            pausedElapsedSeconds: nil
        )
    }
}

#Preview("Notification", as: .content, using: ReadingSessionWidgetAttributes.preview) {
   ReadingSessionWidgetLiveActivity()
} contentStates: {
    ReadingSessionWidgetAttributes.ContentState.starting
    ReadingSessionWidgetAttributes.ContentState.reading
}

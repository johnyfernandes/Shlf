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

    var themeColor: Color {
        Color(hex: themeColorHex) ?? .cyan
    }

    var coverImageURL: URL? {
        guard let coverImageURLString else { return nil }
        return URL(string: coverImageURLString)
    }
}

struct ReadingSessionWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReadingSessionWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            ReadingSessionLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.fill")
                        .font(.title2)
                        .foregroundStyle(context.attributes.themeColor)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 3) {
                            Text("+\(context.state.xpEarned)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }

                        Text("\(context.state.currentPage)/\(context.attributes.totalPages)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.attributes.bookTitle)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(context.attributes.bookAuthor)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        let progress = Double(context.state.currentPage) / Double(max(context.attributes.totalPages, 1))
                        ProgressView(value: progress)
                            .tint(context.attributes.themeColor)

                        // Stats row
                        HStack {
                            if context.state.isPaused {
                                HStack(spacing: 4) {
                                    Image(systemName: "pause.circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                    Text("Paused")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                }

                                if let pausedElapsed = context.state.pausedElapsedSeconds {
                                    Text(formattedElapsed(seconds: pausedElapsed))
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                        .foregroundStyle(.orange)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(context.attributes.themeColor)
                                    Text(context.state.timerStartTime, style: .timer)
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .monospacedDigit()
                                }
                            }

                            Spacer()

                            Text("\(context.state.currentPage) / \(context.attributes.totalPages)")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "book.fill")
                    .foregroundStyle(context.attributes.themeColor)
            } compactTrailing: {
                Text("\(context.state.currentPage)/\(context.attributes.totalPages)")
                    .foregroundStyle(context.attributes.themeColor)
                    .font(.caption2)
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
                        Text(context.state.timerStartTime, style: .timer)
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                .frame(width: 72, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 8) {
                liveActionButton(
                    title: "-1",
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
                    title: "+1",
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

private func formattedElapsed(seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let remainingSeconds = seconds % 60

    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
    }
    return String(format: "%02d:%02d", minutes, remainingSeconds)
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
            coverImageURLString: "https://covers.openlibrary.org/b/isbn/0140280197-L.jpg"
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

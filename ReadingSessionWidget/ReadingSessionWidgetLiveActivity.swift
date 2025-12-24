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

    var themeColor: Color {
        Color(hex: themeColorHex) ?? .cyan
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
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "book.fill")
                    .foregroundStyle(context.attributes.themeColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.bookTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.attributes.bookAuthor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Page indicator
                Text("\(context.state.currentPage)/\(context.attributes.totalPages)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(context.attributes.themeColor)
            }

            // Progress
            ProgressView(value: Double(context.state.currentPage), total: Double(context.attributes.totalPages))
                .tint(context.attributes.themeColor)

            // Stats
            HStack {
                if context.state.isPaused {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text("Paused")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if let pausedElapsed = context.state.pausedElapsedSeconds {
                        Text(formattedElapsed(seconds: pausedElapsed))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(context.state.timerStartTime, style: .timer)
                            .font(.caption)
                            .monospacedDigit()
                    }
                }

                Spacer()

                Label("\(context.state.pagesRead) read", systemImage: "book.pages")
                    .font(.caption)

                Spacer()

                Label("+\(context.state.xpEarned)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            // Page controls
            HStack(spacing: 8) {
                Button(intent: DecrementPageIntent()) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))

                Button(intent: IncrementPageIntent()) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(context.attributes.themeColor)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.2))
        .activitySystemActionForegroundColor(context.attributes.themeColor)
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
            themeColorHex: "#00CED1" // Default cyan for preview
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

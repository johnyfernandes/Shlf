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
    }

    // Fixed non-changing properties about your activity go here!
    var bookTitle: String
    var bookAuthor: String
    var totalPages: Int
    var startPage: Int
    var startTime: Date
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.bookTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)

                        Text(context.attributes.bookAuthor)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
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

                        Text("\(context.state.pagesRead) pages")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // Progress bar
                        let progress = Double(context.state.currentPage) / Double(max(context.attributes.totalPages, 1))
                        ProgressView(value: progress)
                            .tint(.cyan)

                        // Stats row
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.cyan)
                                Text(context.attributes.startTime, style: .timer)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .monospacedDigit()
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
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                Text("\(context.state.pagesRead)")
                    .foregroundStyle(.cyan)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "book.fill")
            }
            .keylineTint(.cyan)
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
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading) {
                    Text(context.attributes.bookTitle)
                        .font(.headline)
                        .lineLimit(1)
                    Text(context.attributes.bookAuthor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Progress
            ProgressView(value: Double(context.state.currentPage), total: Double(context.attributes.totalPages))
                .tint(.cyan)

            // Stats
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(context.attributes.startTime, style: .timer)
                        .font(.caption)
                        .monospacedDigit()
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
                .tint(.cyan)
            }
        }
        .padding()
        .activityBackgroundTint(.black.opacity(0.2))
        .activitySystemActionForegroundColor(.cyan)
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
            startTime: Date().addingTimeInterval(-600) // 10 minutes ago
        )
    }
}

extension ReadingSessionWidgetAttributes.ContentState {
    fileprivate static var starting: ReadingSessionWidgetAttributes.ContentState {
        ReadingSessionWidgetAttributes.ContentState(
            currentPage: 5,
            pagesRead: 5,
            xpEarned: 15
        )
    }

    fileprivate static var reading: ReadingSessionWidgetAttributes.ContentState {
        ReadingSessionWidgetAttributes.ContentState(
            currentPage: 25,
            pagesRead: 25,
            xpEarned: 75
        )
    }
}

#Preview("Notification", as: .content, using: ReadingSessionWidgetAttributes.preview) {
   ReadingSessionWidgetLiveActivity()
} contentStates: {
    ReadingSessionWidgetAttributes.ContentState.starting
    ReadingSessionWidgetAttributes.ContentState.reading
}

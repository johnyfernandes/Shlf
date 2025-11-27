//
//  ReadingSessionWidgetLiveActivity.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct ReadingSessionWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var currentPage: Int
        var pagesRead: Int
        var elapsedMinutes: Int
        var xpEarned: Int
    }

    // Fixed non-changing properties about your activity go here!
    var bookTitle: String
    var bookAuthor: String
    var totalPages: Int
    var startPage: Int
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
                    HStack {
                        Image(systemName: "book.fill")
                            .foregroundStyle(.cyan)
                        Text(context.attributes.bookTitle)
                            .font(.caption)
                            .lineLimit(2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("+\(context.state.xpEarned)")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Text("\(context.state.pagesRead) pages")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.elapsedMinutes)m", systemImage: "clock")
                            .font(.caption)

                        Spacer()

                        Text("\(context.state.currentPage)/\(context.attributes.totalPages)")
                            .font(.caption)
                    }
                    .padding(.horizontal)
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
                Label("\(context.state.elapsedMinutes)m", systemImage: "clock")
                    .font(.caption)

                Spacer()

                Label("\(context.state.pagesRead) read", systemImage: "book.pages")
                    .font(.caption)

                Spacer()

                Label("+\(context.state.xpEarned)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
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
            startPage: 0
        )
    }
}

extension ReadingSessionWidgetAttributes.ContentState {
    fileprivate static var starting: ReadingSessionWidgetAttributes.ContentState {
        ReadingSessionWidgetAttributes.ContentState(
            currentPage: 5,
            pagesRead: 5,
            elapsedMinutes: 10,
            xpEarned: 15
        )
    }

    fileprivate static var reading: ReadingSessionWidgetAttributes.ContentState {
        ReadingSessionWidgetAttributes.ContentState(
            currentPage: 25,
            pagesRead: 25,
            elapsedMinutes: 45,
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

//
//  ReadingSessionWidget.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import WidgetKit
import SwiftUI

struct ReadingWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let xpToday: Int
    let streak: Int
}

struct ReadingWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadingWidgetEntry {
        ReadingWidgetEntry(
            date: Date(),
            title: "The Midnight Library",
            author: "Matt Haig",
            currentPage: 120,
            totalPages: 304,
            xpToday: 80,
            streak: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingWidgetEntry>) -> Void) {
        let now = Date()
        let entries = [
            placeholder(in: context),
            ReadingWidgetEntry(
                date: now.addingTimeInterval(60 * 30),
                title: "Project Hail Mary",
                author: "Andy Weir",
                currentPage: 210,
                totalPages: 475,
                xpToday: 140,
                streak: 6
            )
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ReadingSessionWidgetEntryView: View {
    var entry: ReadingWidgetEntry

    var progress: Double {
        guard entry.totalPages > 0 else { return 0 }
        return Double(entry.currentPage) / Double(entry.totalPages)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color.cyan.opacity(0.85),
                    Color.blue.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(entry.author)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                        .tint(.white)
                        .scaleEffect(x: 1, y: 1.2, anchor: .center)

                    HStack {
                        Label("\(entry.currentPage)/\(entry.totalPages)", systemImage: "book.pages")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Label("+\(entry.xpToday) XP", systemImage: "bolt.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 8) {
                    Label("\(entry.streak) day streak", systemImage: "flame.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Keep going →")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding()
        }
    }
}

struct ReadingSessionWidget: Widget {
    let kind: String = "ReadingSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                ReadingSessionWidgetEntryView(entry: entry)
                    .containerBackground(.clear, for: .widget)
            } else {
                ReadingSessionWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Reading Pulse")
        .description("Glance your progress, XP, and streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

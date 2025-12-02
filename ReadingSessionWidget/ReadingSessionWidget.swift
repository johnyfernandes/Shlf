//
//  ReadingSessionWidget.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import WidgetKit
import SwiftUI
import AppIntents

struct ReadingWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let xpToday: Int
    let streak: Int
}

struct ReadingWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ReadingWidgetEntry
    typealias Intent = ReadingWidgetConfigurationAppIntent

    func placeholder(in context: Context) -> ReadingWidgetEntry {
        ReadingWidgetEntry(
            date: Date(),
            title: ReadingWidgetAppEntity.sample.title,
            author: ReadingWidgetAppEntity.sample.author,
            currentPage: ReadingWidgetAppEntity.sample.currentPage,
            totalPages: ReadingWidgetAppEntity.sample.totalPages,
            xpToday: ReadingWidgetAppEntity.sample.xpToday,
            streak: ReadingWidgetAppEntity.sample.streak
        )
    }

    func snapshot(for configuration: ReadingWidgetConfigurationAppIntent, in context: Context) async -> ReadingWidgetEntry {
        makeEntry(for: configuration) ?? placeholder(in: context)
    }

    func timeline(for configuration: ReadingWidgetConfigurationAppIntent, in context: Context) async -> Timeline<ReadingWidgetEntry> {
        let entry = makeEntry(for: configuration) ?? placeholder(in: context)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60 * 30)))
    }

    private func makeEntry(for config: ReadingWidgetConfigurationAppIntent) -> ReadingWidgetEntry? {
        if let book = config.book {
            return ReadingWidgetEntry(
                date: Date(),
                title: book.title,
                author: book.author,
                currentPage: book.currentPage,
                totalPages: max(book.totalPages, 1),
                xpToday: book.xpToday,
                streak: book.streak
            )
        }

        if let data = try? ReadingWidgetPersistence.shared.load(),
           let first = data.books.first {
            return ReadingWidgetEntry(
                date: Date(),
                title: first.title,
                author: first.author,
                currentPage: first.currentPage,
                totalPages: max(first.totalPages, 1),
                xpToday: first.xpToday,
                streak: first.streak
            )
        }

        let sample = ReadingWidgetAppEntity.sample
        return ReadingWidgetEntry(
            date: Date(),
            title: sample.title,
            author: sample.author,
            currentPage: sample.currentPage,
            totalPages: max(sample.totalPages, 1),
            xpToday: sample.xpToday,
            streak: sample.streak
        )
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
                    Color(.systemCyan).opacity(0.92),
                    Color(.systemBlue).opacity(0.9)
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
        AppIntentConfiguration(kind: kind, intent: ReadingWidgetConfigurationAppIntent.self, provider: ReadingWidgetProvider()) { entry in
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

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
    let isEmpty: Bool

    var pagesToday: Int {
        max(0, xpToday / 10)
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
    }
}

struct ReadingWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ReadingWidgetEntry
    typealias Intent = ReadingWidgetConfigurationAppIntent

    func placeholder(in context: Context) -> ReadingWidgetEntry {
        ReadingWidgetEntry(
            date: Date(),
            title: "No book selected",
            author: "",
            currentPage: 0,
            totalPages: 0,
            xpToday: 0,
            streak: 0,
            isEmpty: true
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
                streak: book.streak,
                isEmpty: false
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
                streak: first.streak,
                isEmpty: false
            )
        }

        return ReadingWidgetEntry(
            date: Date(),
            title: "No book selected",
            author: "",
            currentPage: 0,
            totalPages: 0,
            xpToday: 0,
            streak: 0,
            isEmpty: true
        )
    }
}

struct ReadingSessionWidgetEntryView: View {
    var entry: ReadingWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        ZStack {
            if family == .systemSmall {
                smallLayout
            } else {
                mediumLayout
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(entry.author)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: entry.progress)
                .tint(.white)
                .shadow(color: .white.opacity(0.2), radius: 4)

            HStack {
                Label("\(entry.currentPage)/\(entry.totalPages)", systemImage: "book.pages")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Text("\(Int(entry.progress * 100))%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var statPills: some View {
        HStack(spacing: 8) {
            pill(icon: "bolt.fill", text: "Today \(entry.xpToday) XP", tint: .yellow)
            pill(icon: "flame.fill", text: "\(entry.streak)d streak", tint: .orange)
        }
    }

    private func pill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.2), in: Capsule())
    }

    private var smallLayout: some View {
        Group {
            if entry.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    progressBar
                    statPills
                }
            }
        }
        .padding()
    }

    private var mediumLayout: some View {
        Group {
            if entry.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    progressBar

                    HStack {
                        pill(icon: "bolt.fill", text: "Today \(entry.xpToday) XP", tint: .yellow)
                        Spacer()
                        pill(icon: "flame.fill", text: "\(entry.streak)d streak", tint: .orange)
                    }

                    HStack {
                        Label("\(entry.pagesToday) pages today", systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.9))
                        Spacer()
                        Text("Keep it up →")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No book selected", systemImage: "book.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Pick a book in the widget settings to see your progress here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

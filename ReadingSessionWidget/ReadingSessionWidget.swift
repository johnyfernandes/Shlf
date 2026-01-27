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
    // Active session state
    let hasActiveSession: Bool
    let isSessionPaused: Bool
    let sessionPagesRead: Int
    let sessionElapsedMinutes: Int

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
            isEmpty: true,
            hasActiveSession: false,
            isSessionPaused: false,
            sessionPagesRead: 0,
            sessionElapsedMinutes: 0
        )
    }

    func snapshot(for configuration: ReadingWidgetConfigurationAppIntent, in context: Context) async -> ReadingWidgetEntry {
        makeEntry(for: configuration) ?? placeholder(in: context)
    }

    func timeline(for configuration: ReadingWidgetConfigurationAppIntent, in context: Context) async -> Timeline<ReadingWidgetEntry> {
        let entry = makeEntry(for: configuration) ?? placeholder(in: context)

        // Use aggressive refresh policy during active sessions for real-time updates
        let refreshInterval: TimeInterval = entry.hasActiveSession ? 60 : (60 * 30) // 1 min during session, 30 min otherwise
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(refreshInterval)))
    }

    private func makeEntry(for config: ReadingWidgetConfigurationAppIntent) -> ReadingWidgetEntry? {
        if let book = config.book {
            let sessionPagesRead = book.hasActiveSession ? max(0, book.currentPage - (book.sessionStartPage ?? book.currentPage)) : 0
            let sessionElapsedMinutes: Int
            if book.hasActiveSession, let startTime = book.sessionStartTime {
                sessionElapsedMinutes = max(0, Int(Date().timeIntervalSince(startTime) / 60))
            } else {
                sessionElapsedMinutes = 0
            }

            return ReadingWidgetEntry(
                date: Date(),
                title: book.title,
                author: book.author,
                currentPage: book.currentPage,
                totalPages: max(book.totalPages, 1),
                xpToday: book.xpToday,
                streak: book.streak,
                isEmpty: false,
                hasActiveSession: book.hasActiveSession,
                isSessionPaused: book.isSessionPaused,
                sessionPagesRead: sessionPagesRead,
                sessionElapsedMinutes: sessionElapsedMinutes
            )
        }

        if let data = try? ReadingWidgetPersistence.shared.load(),
           let first = data.books.first {
            let sessionPagesRead = first.hasActiveSession ? max(0, first.currentPage - (first.sessionStartPage ?? first.currentPage)) : 0
            let sessionElapsedMinutes: Int
            if first.hasActiveSession, let startTime = first.sessionStartTime {
                sessionElapsedMinutes = max(0, Int(Date().timeIntervalSince(startTime) / 60))
            } else {
                sessionElapsedMinutes = 0
            }

            return ReadingWidgetEntry(
                date: Date(),
                title: first.title,
                author: first.author,
                currentPage: first.currentPage,
                totalPages: max(first.totalPages, 1),
                xpToday: first.xpToday,
                streak: first.streak,
                isEmpty: false,
                hasActiveSession: first.hasActiveSession,
                isSessionPaused: first.isSessionPaused,
                sessionPagesRead: sessionPagesRead,
                sessionElapsedMinutes: sessionElapsedMinutes
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
            isEmpty: true,
            hasActiveSession: false,
            isSessionPaused: false,
            sessionPagesRead: 0,
            sessionElapsedMinutes: 0
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
            HStack(spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if entry.hasActiveSession {
                    Image(systemName: entry.isSessionPaused ? "pause.circle.fill" : "circle.circle.fill")
                        .font(.caption)
                        .foregroundStyle(entry.isSessionPaused ? .yellow : .green)
                        .symbolEffect(.pulse, isActive: !entry.isSessionPaused)
                }
            }
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
                Label {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%lld/%lld"),
                            entry.currentPage,
                            entry.totalPages
                        )
                    )
                } icon: {
                    Image(systemName: "book.pages")
                }
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
            pill(
                icon: "bolt.fill",
                text: String.localizedStringWithFormat(
                    String(localized: "Today %lld XP"),
                    entry.xpToday
                ),
                tint: .yellow
            )
            pill(
                icon: "flame.fill",
                text: String.localizedStringWithFormat(
                    String(localized: "%lldd streak"),
                    entry.streak
                ),
                tint: .orange
            )
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

                    if entry.hasActiveSession {
                        // Show active session info
                        activeSessionBanner
                    } else {
                        statPills
                    }
                }
            }
        }
        .padding()
    }

    private var activeSessionBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.isSessionPaused ? "pause.circle.fill" : "book.pages.fill")
                .font(.caption)
                .foregroundStyle(entry.isSessionPaused ? .yellow : .green)

            Text(entry.isSessionPaused ? "Paused" : "Reading")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)

            Spacer()

            Text("\(entry.sessionPagesRead)p · \(entry.sessionElapsedMinutes)m")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }

    private var mediumLayout: some View {
        Group {
            if entry.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    progressBar

                    if entry.hasActiveSession {
                        // Show active session info in medium widget
                        HStack {
                            activeSessionBanner
                            Spacer()
                        }
                    }

                    HStack {
                        pill(icon: "bolt.fill", text: "Today \(entry.xpToday) XP", tint: .yellow)
                        Spacer()
                        pill(icon: "flame.fill", text: "\(entry.streak)d streak", tint: .orange)
                    }

                    if !entry.hasActiveSession {
                        HStack {
                            Label {
                                Text("\(entry.pagesToday) \(String(localized: "pages today"))")
                            } icon: {
                                Image(systemName: "clock")
                            }
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

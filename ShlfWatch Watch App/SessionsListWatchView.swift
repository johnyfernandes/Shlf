//
//  SessionsListWatchView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 28/11/2025.
//

import SwiftUI
import SwiftData
import OSLog

struct SessionsListWatchView: View {
    @Environment(\.modelContext) private var modelContext
    let book: Book

    @Query(sort: \ReadingSession.startDate, order: .reverse) private var allSessions: [ReadingSession]

    private var bookSessions: [ReadingSession] {
        let sessions = allSessions.filter { session in
            guard let sessionBook = session.book else {
                WatchConnectivityManager.logger.warning("Session has no book relationship")
                return false
            }
            return sessionBook.id == book.id
        }
        WatchConnectivityManager.logger.info("Found \(sessions.count) sessions for book \(self.book.title)")
        return sessions
    }

    private var todaysSessions: [ReadingSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return bookSessions.filter { calendar.isDate($0.startDate, inSameDayAs: today) }
    }

    private var olderSessions: [ReadingSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return bookSessions.filter { !calendar.isDate($0.startDate, inSameDayAs: today) }
    }

    var body: some View {
        List {
            // Today's Summary
            if !todaysSessions.isEmpty {
                Section {
                    TodaysSummaryCard(sessions: todaysSessions)
                }
            }

            // Today's Sessions
            if !todaysSessions.isEmpty {
                Section("Today") {
                    ForEach(todaysSessions) { session in
                        NavigationLink(destination: SessionDetailWatchView(session: session)) {
                            SessionRowWatch(session: session)
                        }
                    }
                }
            }

            // Older Sessions
            if !olderSessions.isEmpty {
                Section("Earlier") {
                    ForEach(olderSessions.prefix(10)) { session in
                        NavigationLink(destination: SessionDetailWatchView(session: session)) {
                            SessionRowWatch(session: session)
                        }
                    }
                }
            }

            // Empty State
            if bookSessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("No Sessions Yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TodaysSummaryCard: View {
    let sessions: [ReadingSession]

    private var totalPages: Int {
        sessions.reduce(0) { $0 + ($1.endPage - $1.startPage) }
    }

    private var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    private var totalXP: Int {
        sessions.reduce(0) { $0 + $1.xpEarned }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StatItem(icon: "book.fill", value: "\(totalPages)", label: "pages")
                StatItem(icon: "clock.fill", value: "\(totalMinutes)", label: "min")
                StatItem(icon: "star.fill", value: "\(totalXP)", label: "XP")
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .font(.caption)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SessionRowWatch: View {
    let session: ReadingSession

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: session.startDate, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(session.endPage - session.startPage) pages")
                    .font(.headline)
                Spacer()
                Text("\(session.xpEarned) XP")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }

            HStack {
                Text("\(session.durationMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .foregroundStyle(.secondary)

                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SessionsListWatchView(book: Book(
            title: "Test Book",
            author: "Test Author",
            currentPage: 100,
            bookType: .physical,
            readingStatus: .currentlyReading
        ))
    }
}

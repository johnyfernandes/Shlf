//
//  WidgetDataExporter.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import Foundation
import SwiftData
import WidgetKit

private struct WidgetBookPayload: Codable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let xpToday: Int
    let streak: Int
    // Active session state
    let hasActiveSession: Bool
    let isSessionPaused: Bool
    let sessionStartPage: Int?
    let sessionStartTime: Date?
}

private struct WidgetPersistencePayload: Codable {
    let books: [WidgetBookPayload]
}

/// Writes a lightweight snapshot for the widget to the shared app group container.
@MainActor
enum WidgetDataExporter {
    private static let appGroupId = "group.joaofernandes.Shlf"
    private static let fileName = "reading_widget.json"

    static func exportSnapshot(modelContext: ModelContext) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return
        }

        do {
            let allBooks = try modelContext.fetch(FetchDescriptor<Book>())
            let prioritized = allBooks
                .filter { $0.readingStatus == .currentlyReading }
                .sorted { $0.dateAdded > $1.dateAdded }
            let fallbackWithProgress = allBooks
                .filter { $0.currentPage > 0 }
                .sorted { $0.dateAdded > $1.dateAdded }
            let fallbackAny = allBooks.sorted { $0.dateAdded > $1.dateAdded }

            let selectedBooks: [Book]
            if !prioritized.isEmpty {
                selectedBooks = prioritized
            } else if !fallbackWithProgress.isEmpty {
                selectedBooks = fallbackWithProgress
            } else {
                selectedBooks = fallbackAny
            }

            guard !selectedBooks.isEmpty else {
                let emptyPayload = WidgetPersistencePayload(books: [])
                try persist(payload: emptyPayload, at: containerURL)
                return
            }

            let sessionsDescriptor = FetchDescriptor<ReadingSession>()
            let sessions = try modelContext.fetch(sessionsDescriptor)
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profile = try modelContext.fetch(profileDescriptor).first

            // Fetch active sessions for real-time state
            let activeSessionsDescriptor = FetchDescriptor<ActiveReadingSession>()
            let activeSessions = try modelContext.fetch(activeSessionsDescriptor)

            let payloadBooks = selectedBooks.map { book in
                let xpToday = sessions
                    .filter {
                        $0.countsTowardStats &&
                        $0.book?.id == book.id &&
                        Calendar.current.isDate($0.startDate, inSameDayAs: Date())
                    }
                    .reduce(0) { $0 + $1.xpEarned }

                // Check if this book has an active session
                let activeSession = activeSessions.first { $0.book?.id == book.id }

                return WidgetBookPayload(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    currentPage: book.currentPage,
                    totalPages: book.totalPages ?? 0,
                    xpToday: xpToday,
                    streak: profile?.currentStreak ?? 0,
                    hasActiveSession: activeSession != nil,
                    isSessionPaused: activeSession?.isPaused ?? false,
                    sessionStartPage: activeSession?.startPage,
                    sessionStartTime: activeSession?.startDate
                )
            }

            let payload = WidgetPersistencePayload(books: payloadBooks)

            try persist(payload: payload, at: containerURL)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            // Silently ignore; widget will fall back to sample content
        }
    }

    private static func persist(payload: WidgetPersistencePayload, at containerURL: URL) throws {
        let fileURL = containerURL.appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(payload)
        try data.write(to: fileURL, options: .atomic)
    }
}

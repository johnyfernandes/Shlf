//
//  SessionManager.swift
//  Shlf
//
//  Created by Claude Code on 03/12/2025.
//

import Foundation
import SwiftData
import OSLog

/// Centralized service for managing reading sessions
@MainActor
final class SessionManager {
    private static let logger = Logger(subsystem: "com.shlf.app", category: "SessionManager")

    // MARK: - Fetch Helpers

    /// Fetch recent sessions with limit (optimized for performance)
    /// - Parameters:
    ///   - modelContext: SwiftData context
    ///   - limit: Maximum number of sessions to fetch (default 100)
    ///   - daysBack: Only fetch sessions from last N days (default 90)
    /// - Returns: Array of recent sessions, sorted newest first
    static func fetchRecentSessions(
        in modelContext: ModelContext,
        limit: Int = 100,
        daysBack: Int = 90
    ) throws -> [ReadingSession] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()

        var descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate<ReadingSession> { session in
                session.startDate >= cutoffDate
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return try modelContext.fetch(descriptor)
    }

    /// Fetch sessions for a specific book (optimized)
    static func fetchSessions(
        for book: Book,
        in modelContext: ModelContext,
        limit: Int = 50
    ) throws -> [ReadingSession] {
        let bookId = book.id
        var descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate<ReadingSession> { session in
                session.book?.id == bookId
            },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        return try modelContext.fetch(descriptor)
    }

    // MARK: - Delete Operations

    /// Delete a reading session and recalculate stats
    /// - Parameters:
    ///   - session: Session to delete
    ///   - modelContext: SwiftData model context
    static func deleteSession(_ session: ReadingSession, in modelContext: ModelContext) throws {
        let sessionId = session.id
        logger.info("🗑️ Deleting session: \(sessionId)")

        do {
            let book = session.book
            let wasSyncedToSessions = wasBookSyncedToLatestSession(book)
            let previousPage = book?.currentPage

            // Get profile before deleting
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            let profile = profiles.first

            // Delete the session
            modelContext.delete(session)

            // Save deletion first
            do {
                try modelContext.save()
                logger.info("✅ Session deleted and saved")
            } catch {
                logger.error("❌ Failed to save session deletion: \(error.localizedDescription)")
                throw error
            }

            if let book, wasSyncedToSessions {
                let newPage = latestSessionEndPage(for: book, in: modelContext) ?? 0
                let clampedPage = clampPage(newPage, totalPages: book.totalPages)
                if clampedPage != book.currentPage {
                    book.currentPage = clampedPage
                    if let total = book.totalPages,
                       book.readingStatus == .finished,
                       clampedPage < total {
                        book.readingStatus = .currentlyReading
                        book.dateFinished = nil
                    }
                    try? modelContext.save()
                }
            }

            // Recalculate stats from remaining sessions
            if let profile {
                let engine = GamificationEngine(modelContext: modelContext)
                engine.recalculateStats(for: profile)
                logger.info("📊 Stats recalculated")
            } else {
                logger.warning("⚠️ Deleted session without profile")
            }

            // Save updated stats
            do {
                try modelContext.save()
            } catch {
                logger.error("❌ Failed to save updated stats: \(error.localizedDescription)")
                // Don't throw - session already deleted
            }

            // Sync deletion to Watch (CRITICAL - prevents Watch from showing deleted sessions)
            WatchConnectivityManager.shared.sendSessionDeletionToWatch(sessionIds: [sessionId])

            // Sync updated stats to Watch
            if let profile {
                Task {
                    await WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
                }
            }

            if let book,
               let previousPage,
               previousPage != book.currentPage {
                let delta = book.currentPage - previousPage
                WatchConnectivityManager.shared.sendPageDeltaToWatch(
                    bookUUID: book.id,
                    delta: delta,
                    newPage: book.currentPage
                )
            }

            // Update widget (debounced for performance)
            WidgetUpdateCoordinator.shared.scheduleUpdate(modelContext: modelContext)

        } catch {
            logger.error("❌ Fatal error deleting session: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete multiple sessions and recalculate stats once
    /// - Parameters:
    ///   - sessions: Sessions to delete
    ///   - modelContext: SwiftData model context
    static func deleteSessions(_ sessions: [ReadingSession], in modelContext: ModelContext) throws {
        guard !sessions.isEmpty else { return }

        logger.info("🗑️ Deleting \(sessions.count) sessions using iOS 26 batch delete")

        do {
            let booksById = Dictionary(grouping: sessions.compactMap { $0.book }) { $0.id }
            let books = booksById.values.compactMap { $0.first }
            let bookStates = books.map { book in
                (
                    book: book,
                    wasSynced: wasBookSyncedToLatestSession(book),
                    previousPage: book.currentPage
                )
            }

            // Get profile before deleting
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            let profile = profiles.first

            // Store session IDs before deletion
            let sessionIds = sessions.map { $0.id }

            // iOS 26: Use batch delete API (100x faster - bypasses object loading)
            try modelContext.delete(
                model: ReadingSession.self,
                where: #Predicate { session in
                    sessionIds.contains(session.id)
                }
            )

            // Save deletions first
            do {
                try modelContext.save()
                logger.info("✅ \(sessions.count) sessions batch deleted")
            } catch {
                logger.error("❌ Failed to save batch deletions: \(error.localizedDescription)")
                throw error
            }

            for state in bookStates where state.wasSynced {
                let newPage = latestSessionEndPage(for: state.book, in: modelContext) ?? 0
                let clampedPage = clampPage(newPage, totalPages: state.book.totalPages)
                if clampedPage != state.book.currentPage {
                    state.book.currentPage = clampedPage
                    if let total = state.book.totalPages,
                       state.book.readingStatus == .finished,
                       clampedPage < total {
                        state.book.readingStatus = .currentlyReading
                        state.book.dateFinished = nil
                    }
                }
            }

            // Recalculate stats once from remaining sessions
            if let profile {
                let engine = GamificationEngine(modelContext: modelContext)
                engine.recalculateStats(for: profile)
                try modelContext.save()
                logger.info("📊 Stats recalculated and saved")
            } else {
                logger.warning("⚠️ Batch deleted sessions without profile")
            }

            // Sync deletions to Watch (CRITICAL - batch deletion)
            WatchConnectivityManager.shared.sendSessionDeletionToWatch(sessionIds: sessionIds)

            // Sync updated stats to Watch
            if let profile {
                Task {
                    await WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
                }
            }

            for state in bookStates {
                if state.previousPage != state.book.currentPage {
                    let delta = state.book.currentPage - state.previousPage
                    WatchConnectivityManager.shared.sendPageDeltaToWatch(
                        bookUUID: state.book.id,
                        delta: delta,
                        newPage: state.book.currentPage
                    )
                }
            }

            // Update widget (debounced for performance)
            WidgetUpdateCoordinator.shared.scheduleUpdate(modelContext: modelContext)

        } catch {
            logger.error("❌ Fatal error deleting sessions: \(error.localizedDescription)")
            throw error
        }
    }

    private static func wasBookSyncedToLatestSession(_ book: Book?) -> Bool {
        guard let book else { return false }
        let sessions = book.readingSessions ?? []
        guard let latest = latestSession(from: sessions) else { return false }
        return book.currentPage == latest.endPage
    }

    private static func latestSessionEndPage(for book: Book, in modelContext: ModelContext) -> Int? {
        let bookId = book.id
        let descriptor = FetchDescriptor<ReadingSession>(
            predicate: #Predicate<ReadingSession> { session in
                session.book?.id == bookId
            }
        )
        guard let sessions = try? modelContext.fetch(descriptor),
              let latest = latestSession(from: sessions) else { return nil }
        return latest.endPage
    }

    private static func latestSession(from sessions: [ReadingSession]) -> ReadingSession? {
        sessions.max { sessionDate($0) < sessionDate($1) }
    }

    private static func sessionDate(_ session: ReadingSession) -> Date {
        session.endDate ?? session.startDate
    }

    private static func clampPage(_ value: Int, totalPages: Int?) -> Int {
        let minPage = 0
        let maxPage = totalPages ?? Int.max
        return min(maxPage, max(minPage, value))
    }
}

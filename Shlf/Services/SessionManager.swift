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
            // Get profile before deleting
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            guard let profile = profiles.first else {
                // No profile, just delete
                modelContext.delete(session)
                logger.warning("⚠️ Deleted session without profile")
                return
            }

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

            // Recalculate stats from remaining sessions
            do {
                let engine = GamificationEngine(modelContext: modelContext)
                engine.recalculateStats(for: profile)
                logger.info("📊 Stats recalculated")
            } catch {
                logger.error("❌ Failed to recalculate stats: \(error.localizedDescription)")
                // Don't throw - deletion already saved, just log error
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
            Task {
                await WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
            }

            // Update widget
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)

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

        logger.info("🗑️ Deleting \(sessions.count) sessions")

        do {
            // Get profile before deleting
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(profileDescriptor)
            guard let profile = profiles.first else {
                // No profile, just delete
                for session in sessions {
                    modelContext.delete(session)
                }
                logger.warning("⚠️ Deleted sessions without profile")
                return
            }

            // Store session IDs before deletion
            let sessionIds = sessions.map { $0.id }

            // Delete all sessions
            for session in sessions {
                modelContext.delete(session)
            }

            // Save deletions first
            do {
                try modelContext.save()
                logger.info("✅ \(sessions.count) sessions deleted")
            } catch {
                logger.error("❌ Failed to save deletions: \(error.localizedDescription)")
                throw error
            }

            // Recalculate stats once from remaining sessions
            do {
                let engine = GamificationEngine(modelContext: modelContext)
                engine.recalculateStats(for: profile)
                try modelContext.save()
                logger.info("📊 Stats recalculated and saved")
            } catch {
                logger.error("❌ Failed to recalculate stats: \(error.localizedDescription)")
                // Don't throw - deletions already saved
            }

            // Sync deletions to Watch (CRITICAL - batch deletion)
            WatchConnectivityManager.shared.sendSessionDeletionToWatch(sessionIds: sessionIds)

            // Sync updated stats to Watch
            Task {
                await WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
            }

            // Update widget
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)

        } catch {
            logger.error("❌ Fatal error deleting sessions: \(error.localizedDescription)")
            throw error
        }
    }
}

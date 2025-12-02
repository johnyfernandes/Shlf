//
//  ActiveSessionCleanup.swift
//  Shlf
//
//  Automatically cleans up stale active reading sessions
//

import Foundation
import SwiftData
import OSLog

@MainActor
struct ActiveSessionCleanup {
    private static let logger = Logger(subsystem: "com.shlf.app", category: "ActiveSessionCleanup")

    /// Cleanup stale active sessions based on user preferences
    /// Should be called on app launch
    static func cleanupStaleSessionsIfNeeded(modelContext: ModelContext) async {
        logger.info("🧹 Checking for stale active sessions...")

        do {
            // Fetch user profile to check auto-end settings
            let profileDescriptor = FetchDescriptor<UserProfile>()
            guard let profile = try modelContext.fetch(profileDescriptor).first else {
                logger.info("No profile found, skipping cleanup")
                return
            }

            // Check if auto-end is enabled
            guard profile.autoEndSessionEnabled else {
                logger.info("Auto-end disabled, skipping cleanup")
                return
            }

            let autoEndMinutes = profile.autoEndSessionHours * 60

            // Fetch all active sessions
            let sessionDescriptor = FetchDescriptor<ActiveReadingSession>()
            let activeSessions = try modelContext.fetch(sessionDescriptor)

            guard !activeSessions.isEmpty else {
                logger.info("No active sessions to clean up")
                return
            }

            // Check each session for staleness
            var cleanedCount = 0
            for session in activeSessions {
                if session.shouldAutoEnd(autoEndMinutes: autoEndMinutes) {
                    logger.info("🗑️ Auto-ending stale session: \(session.id) (paused at: \(session.pausedAt?.formatted() ?? "unknown"))")

                    // Delete the stale session
                    modelContext.delete(session)
                    cleanedCount += 1

                    // Notify Watch and end Live Activity
                    WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: session.id)
                    await ReadingSessionActivityManager.shared.endActivity()
                }
            }

            if cleanedCount > 0 {
                try modelContext.save()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                logger.info("✅ Cleaned up \(cleanedCount) stale session(s)")
            } else {
                logger.info("No stale sessions found")
            }
        } catch {
            logger.error("Failed to cleanup stale sessions: \(error)")
        }
    }

    /// Manually trigger cleanup for a specific active session
    /// Useful for periodic background checks
    static func cleanupSessionIfStale(_ session: ActiveReadingSession, autoEndMinutes: Int, modelContext: ModelContext) async -> Bool {
        guard session.shouldAutoEnd(autoEndMinutes: autoEndMinutes) else {
            return false
        }

        logger.info("🗑️ Auto-ending stale session: \(session.id)")
        modelContext.delete(session)

        // Notify Watch and end Live Activity
        WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: session.id)
        await ReadingSessionActivityManager.shared.endActivity()

        do {
            try modelContext.save()
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            return true
        } catch {
            logger.error("Failed to save after cleanup: \(error)")
            return false
        }
    }
}

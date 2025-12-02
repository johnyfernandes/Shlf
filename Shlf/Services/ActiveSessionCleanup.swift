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

    /// Cleanup stale active sessions and orphaned Live Activities
    /// Should be called on app launch
    static func cleanupStaleSessionsIfNeeded(modelContext: ModelContext) async {
        logger.info("🧹 Checking for stale active sessions and orphaned Live Activities...")

        // First, check for orphaned Live Activity (Live Activity running but no ActiveReadingSession)
        await checkForOrphanedLiveActivity(modelContext: modelContext)

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

            let autoEndHours = profile.autoEndSessionHours

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
                if session.shouldAutoEnd(inactivityHours: autoEndHours) {
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

    /// Check for orphaned Live Activity (Live Activity running without corresponding ActiveReadingSession)
    private static func checkForOrphanedLiveActivity(modelContext: ModelContext) async {
        // Check if Live Activity is currently active
        guard ReadingSessionActivityManager.shared.isActive else {
            logger.info("No Live Activity running")
            return
        }

        logger.info("🔍 Live Activity detected, checking for corresponding ActiveReadingSession...")

        do {
            // Fetch all active sessions
            let sessionDescriptor = FetchDescriptor<ActiveReadingSession>()
            let activeSessions = try modelContext.fetch(sessionDescriptor)

            if activeSessions.isEmpty {
                // Orphaned Live Activity detected!
                logger.warning("⚠️ Orphaned Live Activity detected (no ActiveReadingSession found) - ending it")
                await ReadingSessionActivityManager.shared.endActivity()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            } else {
                logger.info("✅ Live Activity has corresponding ActiveReadingSession")
            }
        } catch {
            logger.error("Failed to check for orphaned Live Activity: \(error)")
        }
    }

    /// Manually trigger cleanup for a specific active session
    /// Useful for periodic background checks
    static func cleanupSessionIfStale(_ session: ActiveReadingSession, autoEndHours: Int, modelContext: ModelContext) async -> Bool {
        guard session.shouldAutoEnd(inactivityHours: autoEndHours) else {
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

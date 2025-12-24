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
            var profileDescriptor = FetchDescriptor<UserProfile>()
            profileDescriptor.fetchLimit = 1 // Only need one profile
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

            // Fetch all active sessions (iOS 26: Add limit for safety)
            var sessionDescriptor = FetchDescriptor<ActiveReadingSession>()
            sessionDescriptor.fetchLimit = 100 // Sanity limit
            let activeSessions = try modelContext.fetch(sessionDescriptor)

            guard !activeSessions.isEmpty else {
                logger.info("No active sessions to clean up")
                return
            }

            // Check each session for staleness
            var cleanedCount = 0
            for session in activeSessions {
                if session.shouldAutoEnd(inactivityHours: autoEndHours) {
                    logger.info("🗑️ Auto-ending stale session: \(session.id) (last updated: \(session.lastUpdated.formatted()))")

                    // CRITICAL: Notify Watch BEFORE deleting to prevent race condition
                    // If we delete first, Watch might send update and recreate session
                    WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: session.id)
                    await ReadingSessionActivityManager.shared.endActivity()

                    // Small delay to ensure Watch processes end message
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                    // Now safe to delete
                    modelContext.delete(session)
                    cleanedCount += 1
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
    /// OR restore Live Activity from ActiveReadingSession if it was lost due to crash
    private static func checkForOrphanedLiveActivity(modelContext: ModelContext) async {
        do {
            // Fetch all active sessions (iOS 26: Add limit for safety)
            var sessionDescriptor = FetchDescriptor<ActiveReadingSession>()
            sessionDescriptor.fetchLimit = 100 // Sanity limit
            let activeSessions = try modelContext.fetch(sessionDescriptor)

            let liveActivityIsActive = ReadingSessionActivityManager.shared.isActive

            // Case 1: Live Activity running but no ActiveReadingSession
            if liveActivityIsActive && activeSessions.isEmpty {
                logger.warning("⚠️ Orphaned Live Activity detected (no ActiveReadingSession) - ending it")
                await ReadingSessionActivityManager.shared.endActivity()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                return
            }

            // Case 2: ActiveReadingSession exists but no Live Activity (likely crashed)
            if !liveActivityIsActive && !activeSessions.isEmpty {
                logger.info("🔄 Restoring Live Activity from ActiveReadingSession after crash")

                guard let session = activeSessions.first,
                      let book = session.book else {
                    logger.warning("Cannot restore Live Activity - session missing book")
                    return
                }

                // Get profile for theme color
                var profileDescriptor = FetchDescriptor<UserProfile>()
                profileDescriptor.fetchLimit = 1
                let profile = try? modelContext.fetch(profileDescriptor).first
                let themeHex = profile?.themeColor.color.toHex() ?? "#00CED1"

                // Restore Live Activity with current session state
                await ReadingSessionActivityManager.shared.startActivity(
                    book: book,
                    currentPage: session.currentPage,
                    startPage: session.startPage,
                    startTime: session.startDate,
                    themeColorHex: themeHex
                )
                logger.info("✅ Live Activity restored successfully")
            } else if liveActivityIsActive && !activeSessions.isEmpty {
                logger.info("✅ Live Activity and ActiveReadingSession in sync")
            } else {
                logger.info("No active sessions or Live Activity")
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

        // CRITICAL: Notify Watch BEFORE deleting to prevent race condition
        WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: session.id)
        await ReadingSessionActivityManager.shared.endActivity()

        // Small delay to ensure Watch processes end message
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Now safe to delete
        modelContext.delete(session)

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

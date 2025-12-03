//
//  SessionManager.swift
//  Shlf
//
//  Created by Claude Code on 03/12/2025.
//

import Foundation
import SwiftData

/// Centralized service for managing reading sessions
@MainActor
final class SessionManager {

    /// Delete a reading session and recalculate stats
    /// - Parameters:
    ///   - session: Session to delete
    ///   - modelContext: SwiftData model context
    static func deleteSession(_ session: ReadingSession, in modelContext: ModelContext) throws {
        // Get profile before deleting
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(profileDescriptor)
        guard let profile = profiles.first else {
            // No profile, just delete
            modelContext.delete(session)
            return
        }

        // Delete the session
        modelContext.delete(session)

        // Save deletion first
        try modelContext.save()

        // Recalculate stats from remaining sessions
        let engine = GamificationEngine(modelContext: modelContext)
        engine.recalculateStats(for: profile)

        // Save updated stats
        try modelContext.save()

        // Sync to Watch
        Task {
            await WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
        }

        // Update widget
        WidgetDataExporter.exportSnapshot(modelContext: modelContext)
    }

    /// Delete multiple sessions and recalculate stats once
    /// - Parameters:
    ///   - sessions: Sessions to delete
    ///   - modelContext: SwiftData model context
    static func deleteSessions(_ sessions: [ReadingSession], in modelContext: ModelContext) throws {
        guard !sessions.isEmpty else { return }

        // Get profile before deleting
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(profileDescriptor)
        guard let profile = profiles.first else {
            // No profile, just delete
            for session in sessions {
                modelContext.delete(session)
            }
            return
        }

        // Delete all sessions
        for session in sessions {
            modelContext.delete(session)
        }

        // Save deletions first
        try modelContext.save()

        // Recalculate stats once from remaining sessions
        let engine = GamificationEngine(modelContext: modelContext)
        engine.recalculateStats(for: profile)

        // Save updated stats
        try modelContext.save()

        // Sync to Watch
        Task {
            await WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
        }

        // Update widget
        WidgetDataExporter.exportSnapshot(modelContext: modelContext)
    }
}

//
//  ReadingSessionActivityManager.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation
import OSLog

#if canImport(ActivityKit)
import ActivityKit

@MainActor
class ReadingSessionActivityManager {
    static let shared = ReadingSessionActivityManager()
    private static let logger = Logger(subsystem: "com.shlf.app", category: "LiveActivity")

    private(set) var currentActivity: Activity<ReadingSessionWidgetAttributes>?

    private var startTime: Date?
    private var startPage: Int = 0

    private init() {}

    // MARK: - Start Activity

    func startActivity(book: Book, currentPage: Int? = nil, startPage: Int? = nil, startTime: Date? = nil, themeColorHex: String = "#00CED1") async {
        // End any existing activity first
        await endActivity()

        let activityStartTime = startTime ?? Date()
        let startPageValue = startPage ?? book.currentPage
        let currentPageValue = currentPage ?? startPageValue
        let pagesRead = currentPageValue - startPageValue
        let xpEarned = estimatedXP(
            pagesRead: pagesRead,
            durationMinutes: max(1, abs(pagesRead * 2))
        )

        let attributes = ReadingSessionWidgetAttributes(
            bookTitle: book.title,
            bookAuthor: book.author,
            totalPages: book.totalPages ?? 0,
            startPage: startPageValue,
            startTime: activityStartTime,
            themeColorHex: themeColorHex
        )

        let initialState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPageValue,
            pagesRead: pagesRead,
            xpEarned: xpEarned,
            isPaused: false
        )

        let activityContent = ActivityContent(state: initialState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            currentActivity = activity
            self.startTime = activityStartTime
            self.startPage = startPageValue

            Self.logger.info("✅ Live Activity started: \(activity.id)")
        } catch {
            Self.logger.error("❌ Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    func updateActivity(currentPage: Int, xpEarned: Int) async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.debug("⚠️ No Live Activity to update (currentActivity is nil)")
            return
        }

        let pagesRead = currentPage - startPage
        let durationMinutes = elapsedMinutes()
        let xpValue = xpEarned == 0 ? estimatedXP(pagesRead: pagesRead, durationMinutes: durationMinutes) : xpEarned

        let newState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPage,
            pagesRead: pagesRead,
            xpEarned: xpValue,
            isPaused: activity.content.state.isPaused
        )

        let updatedContent = ActivityContent(state: newState, staleDate: nil)

        await activity.update(updatedContent)

        Self.logger.info("📊 Live Activity updated: Page \(currentPage), XP \(xpEarned)")
    }

    func updateCurrentPage(_ currentPage: Int) async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.debug("⚠️ No Live Activity to update (currentActivity is nil)")
            return
        }

        let pagesRead = currentPage - startPage
        let xpEarned = estimatedXP(
            pagesRead: pagesRead,
            durationMinutes: elapsedMinutes()
        )

        let newState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPage,
            pagesRead: pagesRead,
            xpEarned: xpEarned,
            isPaused: activity.content.state.isPaused
        )

        let updatedContent = ActivityContent(state: newState, staleDate: nil)

        await activity.update(updatedContent)

        Self.logger.info("📊 Live Activity updated from Watch: Page \(currentPage)")
    }

    // MARK: - Pause/Resume Activity

    func pauseActivity() async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.warning("⚠️ No Live Activity to pause (currentActivity is nil)")
            return
        }

        var newState = activity.content.state
        newState.isPaused = true

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        Self.logger.info("⏸️ Live Activity paused")
    }

    func resumeActivity() async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.warning("⚠️ No Live Activity to resume (currentActivity is nil)")
            return
        }

        var newState = activity.content.state
        newState.isPaused = false

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        Self.logger.info("▶️ Live Activity resumed")
    }

    // MARK: - End Activity

    func endActivity() async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
            Self.logger.info("🔄 Rehydrated Live Activity before ending")
        }

        guard let activity = currentActivity else {
            Self.logger.warning("⚠️ No Live Activity to end (currentActivity is nil)")
            return
        }

        let finalState = activity.content.state
        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        await activity.end(finalContent, dismissalPolicy: .immediate)

        currentActivity = nil
        startTime = nil
        startPage = 0

        Self.logger.info("🛑 Live Activity ended")
    }

    var isActive: Bool {
        currentActivity != nil
    }

    /// Rehydrates the in-memory activity handle and cached metadata after app relaunch.
    /// Picks the most recent ReadingSessionWidget activity if multiple exist.
    func rehydrateExistingActivity() async {
        let active = Activity<ReadingSessionWidgetAttributes>.activities
            .sorted { $0.attributes.startTime > $1.attributes.startTime }
            .first

        guard let active else {
            return
        }

        currentActivity = active
        startPage = active.attributes.startPage
        startTime = active.attributes.startTime
        Self.logger.info("🔄 Rehydrated existing Live Activity: \(active.id)")
    }

    // MARK: - Get Current State

    func getCurrentPage() -> Int? {
        return currentActivity?.content.state.currentPage
    }

    func getCurrentXP() -> Int? {
        return currentActivity?.content.state.xpEarned
    }

    // MARK: - Helpers

    private func elapsedMinutes() -> Int {
        guard let startTime else { return 0 }
        return max(0, Int(Date().timeIntervalSince(startTime) / 60))
    }

    /// Estimate XP for a reading session in progress
    /// Delegates to centralized XPCalculator for consistency
    private func estimatedXP(pagesRead: Int, durationMinutes: Int) -> Int {
        return XPCalculator.calculate(pagesRead: pagesRead, durationMinutes: durationMinutes)
    }
}
#else

@MainActor
class ReadingSessionActivityManager {
    static let shared = ReadingSessionActivityManager()
    func startActivity(book: Book, currentPage: Int? = nil, startPage: Int? = nil, startTime: Date? = nil) async {}
    func updateActivity(currentPage: Int, xpEarned: Int) async {}
    func updateCurrentPage(_ currentPage: Int) async {}
    func pauseActivity() async {}
    func resumeActivity() async {}
    func endActivity() async {}
    var isActive: Bool { false }
    func getCurrentPage() -> Int? { nil }
    func getCurrentXP() -> Int? { nil }
    func rehydrateExistingActivity() async {}
}
#endif

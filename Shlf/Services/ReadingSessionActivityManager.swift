//
//  ReadingSessionActivityManager.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

@MainActor
class ReadingSessionActivityManager {
    static let shared = ReadingSessionActivityManager()

    private(set) var currentActivity: Activity<ReadingSessionWidgetAttributes>?

    private var startTime: Date?
    private var startPage: Int = 0

    private init() {}

    // MARK: - Start Activity

    func startActivity(book: Book, currentPage: Int? = nil) async {
        // End any existing activity first
        await endActivity()

        let now = Date()
        let startingPage = currentPage ?? book.currentPage
        let pagesRead = startingPage - book.currentPage
        let xpEarned = estimatedXP(
            pagesRead: pagesRead,
            durationMinutes: max(1, abs(pagesRead * 2))
        )

        let attributes = ReadingSessionWidgetAttributes(
            bookTitle: book.title,
            bookAuthor: book.author,
            totalPages: book.totalPages ?? 0,
            startPage: book.currentPage,
            startTime: now
        )

        let initialState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: startingPage,
            pagesRead: startingPage - book.currentPage,
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
            startTime = now
            startPage = book.currentPage

            print("✅ Live Activity started: \(activity.id)")
        } catch {
            print("❌ Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    func updateActivity(currentPage: Int, xpEarned: Int) async {
        guard let activity = currentActivity else { return }

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

        print("📊 Live Activity updated: Page \(currentPage), XP \(xpEarned)")
    }

    func updateCurrentPage(_ currentPage: Int) async {
        guard let activity = currentActivity else { return }

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

        print("📊 Live Activity updated from Watch: Page \(currentPage)")
    }

    // MARK: - Pause/Resume Activity

    func pauseActivity() async {
        guard let activity = currentActivity else { return }

        var newState = activity.content.state
        newState.isPaused = true

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        print("⏸️ Live Activity paused")
    }

    func resumeActivity() async {
        guard let activity = currentActivity else { return }

        var newState = activity.content.state
        newState.isPaused = false

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        print("▶️ Live Activity resumed")
    }

    // MARK: - End Activity

    func endActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = activity.content.state
        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        await activity.end(finalContent, dismissalPolicy: .immediate)

        currentActivity = nil
        startTime = nil
        startPage = 0

        print("🛑 Live Activity ended")
    }

    var isActive: Bool {
        currentActivity != nil
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
    func startActivity(book: Book, currentPage: Int? = nil) async {}
    func updateActivity(currentPage: Int, xpEarned: Int) async {}
    func updateCurrentPage(_ currentPage: Int) async {}
    func pauseActivity() async {}
    func resumeActivity() async {}
    func endActivity() async {}
    var isActive: Bool { false }
    func getCurrentPage() -> Int? { nil }
    func getCurrentXP() -> Int? { nil }
}
#endif

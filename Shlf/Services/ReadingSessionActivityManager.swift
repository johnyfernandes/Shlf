//
//  ReadingSessionActivityManager.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import ActivityKit
import Foundation

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
            xpEarned: (startingPage - book.currentPage) * 3,
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

        let newState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPage,
            pagesRead: pagesRead,
            xpEarned: xpEarned,
            isPaused: activity.content.state.isPaused
        )

        let updatedContent = ActivityContent(state: newState, staleDate: nil)

        await activity.update(updatedContent)

        print("📊 Live Activity updated: Page \(currentPage), XP \(xpEarned)")
    }

    func updateCurrentPage(_ currentPage: Int) async {
        guard let activity = currentActivity else { return }

        let pagesRead = currentPage - startPage
        let xpEarned = pagesRead * 3

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
}

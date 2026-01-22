//
//  ReadingSessionIntents.swift
//  ReadingSessionWidget
//
//  Created by João Fernandes on 27/11/2025.
//

import AppIntents
import ActivityKit
import SwiftData
import WidgetKit
import OSLog

private let logger = Logger(subsystem: "com.shlf.app", category: "LiveActivityIntents")

private func currentElapsedSeconds(for activity: Activity<ReadingSessionWidgetAttributes>) -> TimeInterval {
    if activity.content.state.isPaused, let pausedElapsed = activity.content.state.pausedElapsedSeconds {
        return TimeInterval(pausedElapsed)
    }
    return Date().timeIntervalSince(activity.content.state.timerStartTime)
}

struct IncrementPageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Page"

    @MainActor
    func perform() async throws -> some IntentResult {
        // Update Live Activity UI
        for activity in Activity<ReadingSessionWidgetAttributes>.activities {
            let newPage = activity.content.state.currentPage + 1
            let pagesRead = newPage - activity.attributes.startPage

            // Calculate XP using centralized XPCalculator for consistency
            let elapsedSeconds = currentElapsedSeconds(for: activity)
            let elapsedMinutes = max(1, Int(elapsedSeconds / 60))
            let totalXP = XPCalculator.calculate(pagesRead: pagesRead, durationMinutes: elapsedMinutes)

            // Update Live Activity state
            let newState = ReadingSessionWidgetAttributes.ContentState(
                currentPage: newPage,
                pagesRead: pagesRead,
                xpEarned: totalXP,
                isPaused: activity.content.state.isPaused,
                timerStartTime: activity.content.state.timerStartTime,
                pausedElapsedSeconds: activity.content.state.pausedElapsedSeconds
            )
            await activity.update(ActivityContent(state: newState, staleDate: nil))
            logger.info("📈 Live Activity updated: Page \(newPage)")

            // Update app data using SwiftData
            await updateAppData(
                bookTitle: activity.attributes.bookTitle,
                newPage: newPage,
                pagesRead: 1,
                startPage: activity.content.state.currentPage,
                elapsedMinutes: elapsedMinutes
            )
        }

        return .result()
    }
}

struct DecrementPageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Decrement Page"

    @MainActor
    func perform() async throws -> some IntentResult {
        // Update Live Activity UI
        for activity in Activity<ReadingSessionWidgetAttributes>.activities {
            let startPage = activity.attributes.startPage
            let newPage = max(startPage, activity.content.state.currentPage - 1)
            let pagesRead = max(0, newPage - startPage)

            // Calculate XP using centralized XPCalculator for consistency
            let elapsedSeconds = currentElapsedSeconds(for: activity)
            let elapsedMinutes = max(1, Int(elapsedSeconds / 60))
            let totalXP = XPCalculator.calculate(pagesRead: pagesRead, durationMinutes: elapsedMinutes)

            // Update Live Activity state
            let newState = ReadingSessionWidgetAttributes.ContentState(
                currentPage: newPage,
                pagesRead: pagesRead,
                xpEarned: totalXP,
                isPaused: activity.content.state.isPaused,
                timerStartTime: activity.content.state.timerStartTime,
                pausedElapsedSeconds: activity.content.state.pausedElapsedSeconds
            )
            await activity.update(ActivityContent(state: newState, staleDate: nil))
            logger.info("📉 Live Activity updated: Page \(newPage)")

            // Update app data
            await updateAppData(
                bookTitle: activity.attributes.bookTitle,
                newPage: newPage,
                pagesRead: -1,
                startPage: activity.content.state.currentPage,
                elapsedMinutes: elapsedMinutes
            )
        }

        return .result()
    }
}

struct TogglePauseIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause or Resume"

    @MainActor
    func perform() async throws -> some IntentResult {
        for activity in Activity<ReadingSessionWidgetAttributes>.activities {
            let isPaused = activity.content.state.isPaused
            let elapsedSeconds = currentElapsedSeconds(for: activity)

            if isPaused {
                let resumedTimerStart = Date().addingTimeInterval(-elapsedSeconds)
                let newState = ReadingSessionWidgetAttributes.ContentState(
                    currentPage: activity.content.state.currentPage,
                    pagesRead: activity.content.state.pagesRead,
                    xpEarned: activity.content.state.xpEarned,
                    isPaused: false,
                    timerStartTime: resumedTimerStart,
                    pausedElapsedSeconds: nil
                )
                await activity.update(ActivityContent(state: newState, staleDate: nil))
                logger.info("▶️ Live Activity resumed via button")
                await updatePauseState(bookTitle: activity.attributes.bookTitle, shouldPause: false)
            } else {
                let newState = ReadingSessionWidgetAttributes.ContentState(
                    currentPage: activity.content.state.currentPage,
                    pagesRead: activity.content.state.pagesRead,
                    xpEarned: activity.content.state.xpEarned,
                    isPaused: true,
                    timerStartTime: activity.content.state.timerStartTime,
                    pausedElapsedSeconds: Int(elapsedSeconds)
                )
                await activity.update(ActivityContent(state: newState, staleDate: nil))
                logger.info("⏸️ Live Activity paused via button")
                await updatePauseState(bookTitle: activity.attributes.bookTitle, shouldPause: true)
            }
        }

        return .result()
    }
}

// MARK: - Shared App Data Update Logic

@MainActor
private func updateAppData(
    bookTitle: String,
    newPage: Int,
    pagesRead: Int,
    startPage: Int,
    elapsedMinutes: Int
) async {
    do {
        // Access shared SwiftData container
        let container = try SwiftDataConfig.createModelContainer()
        let context = container.mainContext
        WatchConnectivityManager.shared.configure(modelContext: context)
        WatchConnectivityManager.shared.activate()

        // Find the book by title (active reading session book)
        let bookDescriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> { book in
                book.title == bookTitle && book.readingStatusRawValue == "Currently Reading"
            }
        )
        let books = try context.fetch(bookDescriptor)

        guard let book = books.first else {
            logger.warning("Book not found for Live Activity: \(bookTitle)")
            return
        }

        // If there is an active session for this book, update it; otherwise, do nothing (no session to sync)
        let activeDescriptor = FetchDescriptor<ActiveReadingSession>()
        let activeSessions = try context.fetch(activeDescriptor)

        guard let activeSession = activeSessions.first(where: { $0.book?.id == book.id }) else {
            logger.warning("No active session for Live Activity update: \(bookTitle)")
            return
        }

        // Apply the delta once
        activeSession.currentPage = newPage
        activeSession.lastUpdated = Date()
        if activeSession.isPaused, let pausedAt = activeSession.pausedAt {
            activeSession.totalPausedDuration += Date().timeIntervalSince(pausedAt)
        }
        activeSession.isPaused = false
        activeSession.pausedAt = nil
        book.currentPage = newPage

        try context.save()

        // Keep Watch in sync with the authoritative active session
        WatchConnectivityManager.shared.sendActiveSessionToWatch(activeSession)

        logger.info("💾 Live Activity changes saved to SwiftData")

        // Reload widget data
        WidgetDataExporter.exportSnapshot(modelContext: context)
        WidgetCenter.shared.reloadAllTimelines()
        logger.info("🔄 Widget reloaded after Live Activity update")

        // Post notification to refresh UI
        NotificationCenter.default.post(name: Notification.Name("watchStatsUpdated"), object: nil)
        logger.info("📡 Posted UI refresh notification")

    } catch {
        logger.error("❌ Failed to update app data from Live Activity: \(error)")
    }
}

@MainActor
private func updatePauseState(bookTitle: String, shouldPause: Bool) async {
    do {
        let container = try SwiftDataConfig.createModelContainer()
        let context = container.mainContext
        WatchConnectivityManager.shared.configure(modelContext: context)
        WatchConnectivityManager.shared.activate()

        let bookDescriptor = FetchDescriptor<Book>(
            predicate: #Predicate<Book> { book in
                book.title == bookTitle && book.readingStatusRawValue == "Currently Reading"
            }
        )
        let books = try context.fetch(bookDescriptor)

        guard let book = books.first else {
            logger.warning("Book not found for pause toggle: \(bookTitle)")
            return
        }

        let activeDescriptor = FetchDescriptor<ActiveReadingSession>()
        let activeSessions = try context.fetch(activeDescriptor)

        guard let activeSession = activeSessions.first(where: { $0.book?.id == book.id }) else {
            logger.warning("No active session for pause toggle: \(bookTitle)")
            return
        }

        if shouldPause {
            if !activeSession.isPaused {
                activeSession.isPaused = true
                activeSession.pausedAt = Date()
                activeSession.lastUpdated = Date()
            }
        } else {
            if activeSession.isPaused {
                if let pausedAt = activeSession.pausedAt {
                    activeSession.totalPausedDuration += Date().timeIntervalSince(pausedAt)
                }
                activeSession.isPaused = false
                activeSession.pausedAt = nil
                activeSession.lastUpdated = Date()
            }
        }

        try context.save()

        // Keep Watch in sync with the authoritative active session
        WatchConnectivityManager.shared.sendActiveSessionToWatch(activeSession)

        // Reload widget data
        WidgetDataExporter.exportSnapshot(modelContext: context)
        WidgetCenter.shared.reloadAllTimelines()
    } catch {
        logger.error("❌ Failed to toggle pause from Live Activity: \(error)")
    }
}

private func syncToWatch(bookUUID: UUID, pageDelta: Int, profile: UserProfile?) {
    // Send page delta to Watch
    WatchConnectivityManager.shared.sendPageDeltaToWatch(bookUUID: bookUUID, delta: pageDelta)

    // Send updated profile stats to Watch
    if let profile = profile {
        WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
    }
}

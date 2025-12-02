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

struct IncrementPageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Increment Page"

    @MainActor
    func perform() async throws -> some IntentResult {
        // Update Live Activity UI
        for activity in Activity<ReadingSessionWidgetAttributes>.activities {
            let newPage = activity.content.state.currentPage + 1
            let pagesRead = newPage - activity.attributes.startPage

            // Calculate XP matching GamificationEngine (10 XP/page + duration bonus)
            let elapsedMinutes = max(1, Int(Date().timeIntervalSince(activity.attributes.startTime) / 60))
            let baseXP = pagesRead * 10
            let bonusXP: Int
            if elapsedMinutes >= 180 {
                bonusXP = 200
            } else if elapsedMinutes >= 120 {
                bonusXP = 100
            } else if elapsedMinutes >= 60 {
                bonusXP = 50
            } else {
                bonusXP = 0
            }
            let totalXP = baseXP + bonusXP

            // Update Live Activity state
            let newState = ReadingSessionWidgetAttributes.ContentState(
                currentPage: newPage,
                pagesRead: pagesRead,
                xpEarned: totalXP,
                isPaused: activity.content.state.isPaused
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

            // Calculate XP
            let elapsedMinutes = max(1, Int(Date().timeIntervalSince(activity.attributes.startTime) / 60))
            let baseXP = pagesRead * 10
            let bonusXP: Int
            if elapsedMinutes >= 180 {
                bonusXP = 200
            } else if elapsedMinutes >= 120 {
                bonusXP = 100
            } else if elapsedMinutes >= 60 {
                bonusXP = 50
            } else {
                bonusXP = 0
            }
            let totalXP = baseXP + bonusXP

            // Update Live Activity state
            let newState = ReadingSessionWidgetAttributes.ContentState(
                currentPage: newPage,
                pagesRead: pagesRead,
                xpEarned: totalXP,
                isPaused: activity.content.state.isPaused
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

        // If there is an active session for this book, update it instead of creating a new session
        let activeDescriptor = FetchDescriptor<ActiveReadingSession>()
        let activeSessions = try context.fetch(activeDescriptor)

        let pageDelta = newPage - book.currentPage

        if let activeSession = activeSessions.first(where: { $0.book?.id == book.id }) {
            activeSession.currentPage = newPage
            activeSession.lastUpdated = Date()
            activeSession.isPaused = false
            activeSession.pausedAt = nil
            book.currentPage = newPage
            try context.save()

            // Keep Watch in sync with the authoritative active session
            WatchConnectivityManager.shared.sendActiveSessionToWatch(activeSession)
        }
        // Update book progress regardless
        book.currentPage = newPage
        try context.save()

        logger.info("💾 Live Activity changes saved to SwiftData")

        // Reload widget data
        WidgetDataExporter.exportSnapshot(modelContext: context)
        WidgetCenter.shared.reloadAllTimelines()
        logger.info("🔄 Widget reloaded after Live Activity update")

        // Sync to Watch
        syncToWatch(bookUUID: book.id, pageDelta: pageDelta, profile: nil)

        // Post notification to refresh UI
        NotificationCenter.default.post(name: .watchStatsUpdated, object: nil)
        logger.info("📡 Posted UI refresh notification")

    } catch {
        logger.error("❌ Failed to update app data from Live Activity: \(error)")
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

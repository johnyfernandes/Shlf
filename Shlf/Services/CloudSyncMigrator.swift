//
//  CloudSyncMigrator.swift
//  Shlf
//
//  Handles one-way data migration between local and CloudKit stores.
//

import Foundation
import SwiftData

@MainActor
enum CloudSyncMigrator {
    enum MigrationError: Error {
        case missingProfile
    }

    static func migrate(modelContext: ModelContext, to targetMode: SwiftDataConfig.StorageMode) throws {
        let sourceMode = SwiftDataConfig.currentStorageMode()
        guard sourceMode != targetMode else { return }

        try modelContext.save()

        let targetContainer = try SwiftDataConfig.createModelContainer(storageMode: targetMode)
        let targetContext = targetContainer.mainContext

        try purgeAllData(in: targetContext)

        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(profileDescriptor)
        guard let sourceProfile = profiles.first else {
            throw MigrationError.missingProfile
        }

        let profileCopy = UserProfile(
            id: sourceProfile.id,
            totalXP: sourceProfile.totalXP,
            currentStreak: sourceProfile.currentStreak,
            longestStreak: sourceProfile.longestStreak,
            lastReadingDate: sourceProfile.lastReadingDate,
            hasCompletedOnboarding: sourceProfile.hasCompletedOnboarding,
            isProUser: sourceProfile.isProUser,
            cloudSyncEnabled: sourceProfile.cloudSyncEnabled,
            showDescription: sourceProfile.showDescription,
            showMetadata: sourceProfile.showMetadata,
            showSubjects: sourceProfile.showSubjects,
            showReadingHistory: sourceProfile.showReadingHistory,
            showNotes: sourceProfile.showNotes,
            showPublisher: sourceProfile.showPublisher,
            showPublishedDate: sourceProfile.showPublishedDate,
            showLanguage: sourceProfile.showLanguage,
            showISBN: sourceProfile.showISBN,
            showReadingTime: sourceProfile.showReadingTime,
            pageIncrementAmount: sourceProfile.pageIncrementAmount,
            useProgressSlider: sourceProfile.useProgressSlider,
            showSliderButtons: sourceProfile.showSliderButtons,
            useCircularProgressWatch: sourceProfile.useCircularProgressWatch,
            hideAutoSessionsIPhone: sourceProfile.hideAutoSessionsIPhone,
            hideAutoSessionsWatch: sourceProfile.hideAutoSessionsWatch,
            showSettingsOnWatch: sourceProfile.showSettingsOnWatch,
            homeCardOrder: sourceProfile.homeCardOrder
        )
        profileCopy.chartTypeRawValue = sourceProfile.chartTypeRawValue
        profileCopy.heatmapPeriodRawValue = sourceProfile.heatmapPeriodRawValue
        profileCopy.bookDetailSectionOrder = sourceProfile.bookDetailSectionOrder
        profileCopy.autoEndSessionEnabled = sourceProfile.autoEndSessionEnabled
        profileCopy.autoEndSessionHours = sourceProfile.autoEndSessionHours
        targetContext.insert(profileCopy)

        let booksDescriptor = FetchDescriptor<Book>()
        let sourceBooks = try modelContext.fetch(booksDescriptor)
        var bookMap: [UUID: Book] = [:]
        for sourceBook in sourceBooks {
            let book = Book(
                id: sourceBook.id,
                title: sourceBook.title,
                author: sourceBook.author,
                isbn: sourceBook.isbn,
                coverImageURL: sourceBook.coverImageURL,
                totalPages: sourceBook.totalPages,
                currentPage: sourceBook.currentPage,
                bookType: sourceBook.bookType,
                readingStatus: sourceBook.readingStatus,
                dateAdded: sourceBook.dateAdded,
                dateStarted: sourceBook.dateStarted,
                dateFinished: sourceBook.dateFinished,
                notes: sourceBook.notes,
                rating: sourceBook.rating,
                bookDescription: sourceBook.bookDescription,
                subjects: sourceBook.subjects,
                publisher: sourceBook.publisher,
                publishedDate: sourceBook.publishedDate,
                language: sourceBook.language,
                openLibraryWorkID: sourceBook.openLibraryWorkID,
                openLibraryEditionID: sourceBook.openLibraryEditionID
            )
            book.savedCurrentPage = sourceBook.savedCurrentPage
            targetContext.insert(book)
            bookMap[sourceBook.id] = book
        }

        let goalDescriptor = FetchDescriptor<ReadingGoal>()
        let goals = try modelContext.fetch(goalDescriptor)
        for sourceGoal in goals {
            let goal = ReadingGoal(
                id: sourceGoal.id,
                type: sourceGoal.type,
                targetValue: sourceGoal.targetValue,
                currentValue: sourceGoal.currentValue,
                startDate: sourceGoal.startDate,
                endDate: sourceGoal.endDate,
                isCompleted: sourceGoal.isCompleted,
                createdAt: sourceGoal.createdAt
            )
            goal.profile = profileCopy
            targetContext.insert(goal)
        }

        let achievementDescriptor = FetchDescriptor<Achievement>()
        let achievements = try modelContext.fetch(achievementDescriptor)
        for sourceAchievement in achievements {
            let achievement = Achievement(
                id: sourceAchievement.id,
                type: sourceAchievement.type,
                unlockedAt: sourceAchievement.unlockedAt,
                isNew: sourceAchievement.isNew
            )
            achievement.profile = profileCopy
            targetContext.insert(achievement)
        }

        let sessionDescriptor = FetchDescriptor<ReadingSession>()
        let sessions = try modelContext.fetch(sessionDescriptor)
        for sourceSession in sessions {
            guard let bookId = sourceSession.book?.id,
                  let book = bookMap[bookId] else { continue }
            let session = ReadingSession(
                id: sourceSession.id,
                startDate: sourceSession.startDate,
                endDate: sourceSession.endDate,
                startPage: sourceSession.startPage,
                endPage: sourceSession.endPage,
                durationMinutes: sourceSession.durationMinutes,
                xpEarned: sourceSession.xpEarned,
                isAutoGenerated: sourceSession.isAutoGenerated,
                countsTowardStats: sourceSession.countsTowardStats,
                isImported: sourceSession.isImported,
                book: book
            )
            session.xpAwarded = sourceSession.xpAwarded
            targetContext.insert(session)
        }

        let positionDescriptor = FetchDescriptor<BookPosition>()
        let positions = try modelContext.fetch(positionDescriptor)
        for sourcePosition in positions {
            guard let bookId = sourcePosition.book?.id,
                  let book = bookMap[bookId] else { continue }
            let position = BookPosition(
                id: sourcePosition.id,
                book: book,
                pageNumber: sourcePosition.pageNumber,
                lineNumber: sourcePosition.lineNumber,
                timestamp: sourcePosition.timestamp,
                note: sourcePosition.note
            )
            targetContext.insert(position)
        }

        let quoteDescriptor = FetchDescriptor<Quote>()
        let quotes = try modelContext.fetch(quoteDescriptor)
        for sourceQuote in quotes {
            guard let bookId = sourceQuote.book?.id,
                  let book = bookMap[bookId] else { continue }
            let quote = Quote(
                id: sourceQuote.id,
                book: book,
                text: sourceQuote.text,
                pageNumber: sourceQuote.pageNumber,
                dateAdded: sourceQuote.dateAdded,
                note: sourceQuote.note,
                isFavorite: sourceQuote.isFavorite
            )
            targetContext.insert(quote)
        }

        let activeDescriptor = FetchDescriptor<ActiveReadingSession>()
        let activeSessions = try modelContext.fetch(activeDescriptor)
        for sourceActive in activeSessions {
            guard let book = bookMap[sourceActive.book?.id ?? UUID()] else { continue }
            let active = ActiveReadingSession(
                id: sourceActive.id,
                book: book,
                startDate: sourceActive.startDate,
                currentPage: sourceActive.currentPage,
                startPage: sourceActive.startPage,
                isPaused: sourceActive.isPaused,
                pausedAt: sourceActive.pausedAt,
                totalPausedDuration: sourceActive.totalPausedDuration,
                lastUpdated: sourceActive.lastUpdated,
                sourceDevice: sourceActive.sourceDevice
            )
            targetContext.insert(active)
        }

        try targetContext.save()
    }

    private static func purgeAllData(in context: ModelContext) throws {
        let sessionDescriptor = FetchDescriptor<ReadingSession>()
        let sessions = try context.fetch(sessionDescriptor)
        for session in sessions {
            context.delete(session)
        }

        let goalDescriptor = FetchDescriptor<ReadingGoal>()
        let goals = try context.fetch(goalDescriptor)
        for goal in goals {
            context.delete(goal)
        }

        let achievementDescriptor = FetchDescriptor<Achievement>()
        let achievements = try context.fetch(achievementDescriptor)
        for achievement in achievements {
            context.delete(achievement)
        }

        let activeDescriptor = FetchDescriptor<ActiveReadingSession>()
        let activeSessions = try context.fetch(activeDescriptor)
        for session in activeSessions {
            context.delete(session)
        }

        let positionDescriptor = FetchDescriptor<BookPosition>()
        let positions = try context.fetch(positionDescriptor)
        for position in positions {
            context.delete(position)
        }

        let quoteDescriptor = FetchDescriptor<Quote>()
        let quotes = try context.fetch(quoteDescriptor)
        for quote in quotes {
            context.delete(quote)
        }

        let bookDescriptor = FetchDescriptor<Book>()
        let books = try context.fetch(bookDescriptor)
        for book in books {
            context.delete(book)
        }

        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(profileDescriptor)
        for profile in profiles {
            context.delete(profile)
        }

        try context.save()
    }
}

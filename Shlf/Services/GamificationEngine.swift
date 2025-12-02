//
//  GamificationEngine.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class GamificationEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - XP Calculation

    /// Calculate XP for a reading session
    /// Delegates to centralized XPCalculator for consistency
    func calculateXP(for session: ReadingSession) -> Int {
        return XPCalculator.calculate(for: session)
    }

    func awardXP(_ amount: Int, to profile: UserProfile) {
        let previousLevel = profile.currentLevel
        profile.totalXP += amount

        // Check for level-up achievements
        let newLevel = profile.currentLevel
        if newLevel > previousLevel {
            checkLevelAchievements(level: newLevel, profile: profile)
        }

        // Update goals
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: profile)
    }

    // MARK: - Streak Management

    func updateStreak(for profile: UserProfile, sessionDate: Date = Date()) {
        let calendar = Calendar.current

        guard let lastReadingDate = profile.lastReadingDate else {
            // First reading session ever
            profile.currentStreak = 1
            profile.longestStreak = 1
            profile.lastReadingDate = sessionDate
            return
        }

        let daysSinceLastReading = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastReadingDate),
            to: calendar.startOfDay(for: sessionDate)
        ).day ?? 0

        switch daysSinceLastReading {
        case 0:
            // Same day, no change to streak
            break
        case 1:
            // Consecutive day, increment streak
            profile.currentStreak += 1
            if profile.currentStreak > profile.longestStreak {
                profile.longestStreak = profile.currentStreak
            }
            profile.lastReadingDate = sessionDate
            checkStreakAchievements(streak: profile.currentStreak, profile: profile)
        default:
            // Streak broken
            profile.currentStreak = 1
            profile.lastReadingDate = sessionDate
        }
    }

    // MARK: - Achievement Checking

    func checkAchievements(for profile: UserProfile) {
        checkBookAchievements(profile: profile)
        checkPageAchievements(profile: profile)
    }

    private func checkBookAchievements(profile: UserProfile) {
        let descriptor = FetchDescriptor<Book>()
        guard let allBooks = try? modelContext.fetch(descriptor) else { return }
        let finishedBooks = allBooks.filter { $0.readingStatus == .finished }
        let count = finishedBooks.count

        let milestones: [(Int, AchievementType)] = [
            (1, .firstBook),
            (10, .tenBooks),
            (50, .fiftyBooks),
            (100, .hundredBooks)
        ]

        for (threshold, achievementType) in milestones {
            if count >= threshold {
                unlockAchievement(achievementType, for: profile)
            }
        }
    }

    private func checkPageAchievements(profile: UserProfile) {
        let descriptor = FetchDescriptor<ReadingSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        let totalPages = sessions.reduce(0) { $0 + $1.pagesRead }

        let milestones: [(Int, AchievementType)] = [
            (100, .hundredPages),
            (1000, .thousandPages),
            (10000, .tenThousandPages)
        ]

        for (threshold, achievementType) in milestones {
            if totalPages >= threshold {
                unlockAchievement(achievementType, for: profile)
            }
        }

        // Check daily reading achievements
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todaySessions = sessions.filter {
            calendar.isDate($0.startDate, inSameDayAs: today)
        }

        let todayPages = todaySessions.reduce(0) { $0 + $1.pagesRead }
        if todayPages >= 100 {
            unlockAchievement(.hundredPagesInDay, for: profile)
        }

        let todayMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        if todayMinutes >= 180 {
            unlockAchievement(.marathonReader, for: profile)
        }
    }

    private func checkStreakAchievements(streak: Int, profile: UserProfile) {
        let milestones: [(Int, AchievementType)] = [
            (7, .sevenDayStreak),
            (30, .thirtyDayStreak),
            (100, .hundredDayStreak)
        ]

        for (threshold, achievementType) in milestones {
            if streak >= threshold {
                unlockAchievement(achievementType, for: profile)
            }
        }
    }

    private func checkLevelAchievements(level: Int, profile: UserProfile) {
        let milestones: [(Int, AchievementType)] = [
            (5, .levelFive),
            (10, .levelTen),
            (20, .levelTwenty)
        ]

        for (threshold, achievementType) in milestones {
            if level >= threshold {
                unlockAchievement(achievementType, for: profile)
            }
        }
    }

    private func unlockAchievement(_ type: AchievementType, for profile: UserProfile) {
        // Check if achievement already exists
        let alreadyUnlocked = (profile.achievements ?? []).contains { $0.type == type }
        guard !alreadyUnlocked else { return }

        let achievement = Achievement(type: type)
        if profile.achievements == nil {
            profile.achievements = []
        }
        profile.achievements?.append(achievement)
        modelContext.insert(achievement)
    }

    // MARK: - Stats Calculation

    func totalBooksRead() -> Int {
        let descriptor = FetchDescriptor<Book>()
        guard let books = try? modelContext.fetch(descriptor) else { return 0 }
        return books.filter { $0.readingStatus == .finished }.count
    }

    func totalPagesRead() -> Int {
        // ONLY count reading sessions (including auto-generated ones)
        // Auto-generated sessions now handle corrections with negative values
        let sessionDescriptor = FetchDescriptor<ReadingSession>()
        let sessionPages = (try? modelContext.fetch(sessionDescriptor))?.reduce(0) { $0 + $1.pagesRead } ?? 0

        return max(0, sessionPages) // Don't show negative if user makes big corrections
    }

    func totalReadingMinutes() -> Int {
        let descriptor = FetchDescriptor<ReadingSession>()
        guard let sessions = try? modelContext.fetch(descriptor) else { return 0 }
        return sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    func booksReadThisYear() -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        let descriptor = FetchDescriptor<Book>()
        guard let books = try? modelContext.fetch(descriptor) else { return 0 }

        return books.filter { book in
            guard book.readingStatus == .finished,
                  let dateFinished = book.dateFinished else { return false }
            return calendar.component(.year, from: dateFinished) == year
        }.count
    }

    func booksReadThisMonth() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        let descriptor = FetchDescriptor<Book>()
        guard let books = try? modelContext.fetch(descriptor) else { return 0 }

        return books.filter { book in
            guard book.readingStatus == .finished,
                  let dateFinished = book.dateFinished else { return false }
            return calendar.component(.year, from: dateFinished) == year &&
                   calendar.component(.month, from: dateFinished) == month
        }.count
    }
}

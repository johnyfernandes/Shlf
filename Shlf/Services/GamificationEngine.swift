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

    /// Recalculate total XP from all sessions (source of truth)
    /// Call this after deleting sessions, removing pages, or to fix stats
    func recalculateStats(for profile: UserProfile) {
        let previousLevel = profile.currentLevel

        // Recalculate XP from tracked sessions only
        let sessionDescriptor = FetchDescriptor<ReadingSession>()
        guard let allSessions = try? modelContext.fetch(sessionDescriptor) else { return }
        let trackedSessions = allSessions.filter { $0.countsTowardStats }

        let totalXP = trackedSessions.reduce(0) { $0 + $1.xpEarned }
        profile.totalXP = totalXP // Set directly, don't add

        // Check for level-up achievements
        let newLevel = profile.currentLevel
        if newLevel > previousLevel {
            checkLevelAchievements(level: newLevel, profile: profile)
        }

        // Recalculate streak
        recalculateStreak(for: profile, sessions: trackedSessions)

        // Update goals
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: profile)

        // Check all achievements
        checkAchievements(for: profile)

        // CRITICAL: Save all changes to persist recalculated stats
        try? modelContext.save()
    }

    func awardXP(_ amount: Int, to profile: UserProfile) {
        let previousLevel = profile.currentLevel

        // Prevent overflow and ensure totalXP never goes negative
        let newTotal = profile.totalXP.addingReportingOverflow(amount)
        if newTotal.overflow {
            profile.totalXP = amount >= 0 ? Int.max : 0
        } else {
            profile.totalXP = max(0, newTotal.partialValue)
        }

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

    /// Recalculate streak from all sessions (source of truth)
    private func recalculateStreak(for profile: UserProfile, sessions: [ReadingSession]) {
        guard !sessions.isEmpty else {
            profile.currentStreak = 0
            profile.longestStreak = 0
            profile.lastReadingDate = nil
            return
        }

        // NOTE: Streak calculation uses current timezone
        // If user travels across timezones, streaks are calculated based on local midnight
        // This is acceptable behavior - users generally expect streaks based on their local day
        let calendar = Calendar.current

        // Sort sessions by date
        let sortedSessions = sessions.sorted { $0.startDate < $1.startDate }

        // Get unique reading days
        let readingDays = Set(sortedSessions.map { calendar.startOfDay(for: $0.startDate) })
        let sortedDays = readingDays.sorted()

        // Calculate longest and current streak
        var longestStreak = 0
        var currentStreakCount = 0

        for (index, day) in sortedDays.enumerated() {
            if index == 0 {
                currentStreakCount = 1
            } else {
                let previousDay = sortedDays[index - 1]
                let daysSince = calendar.dateComponents([.day], from: previousDay, to: day).day ?? 0

                if daysSince == 1 {
                    // Consecutive day
                    currentStreakCount += 1
                } else {
                    // Streak broken
                    longestStreak = max(longestStreak, currentStreakCount)
                    currentStreakCount = 1
                }
            }

            longestStreak = max(longestStreak, currentStreakCount)
        }

        // Check if current streak is still active (read today or yesterday)
        if let lastDay = sortedDays.last {
            let today = calendar.startOfDay(for: Date())
            let daysSinceLastReading = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysSinceLastReading <= 1 {
                // Streak is active
                profile.currentStreak = currentStreakCount
            } else {
                // Streak broken
                profile.currentStreak = 0
            }
        }

        profile.longestStreak = longestStreak
        profile.lastReadingDate = sortedSessions.last?.startDate
    }

    func updateStreak(for profile: UserProfile, sessionDate: Date = Date()) {
        let calendar = Calendar.current

        // Prevent future dates (clock skew protection)
        // Allow small tolerance (60 seconds) for clock drift
        let validSessionDate = min(sessionDate, Date().addingTimeInterval(60))

        guard let lastReadingDate = profile.lastReadingDate else {
            // First reading session ever
            profile.currentStreak = 1
            profile.longestStreak = 1
            profile.lastReadingDate = validSessionDate
            return
        }

        let daysSinceLastReading = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastReadingDate),
            to: calendar.startOfDay(for: validSessionDate)
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
            profile.lastReadingDate = validSessionDate
            checkStreakAchievements(streak: profile.currentStreak, profile: profile)
        default:
            // Streak broken
            profile.currentStreak = 1
            profile.lastReadingDate = validSessionDate
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
        let trackedSessions = sessions.filter { $0.countsTowardStats }

        let totalPages = trackedSessions.reduce(0) { $0 + $1.pagesRead }

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

        let todaySessions = trackedSessions.filter {
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
        // Check if achievement already exists in profile relationship
        let alreadyUnlocked = (profile.achievements ?? []).contains { $0.type == type }
        guard !alreadyUnlocked else { return }

        // Double-check by querying database to prevent race condition
        // (in case another device just inserted the same achievement)
        let typeValue = type.rawValue
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { achievement in
                achievement.typeRawValue == typeValue
            }
        )

        // Fetch and filter by profile manually (avoids optional chain in predicate)
        if let existingAchievements = try? modelContext.fetch(descriptor) {
            let profileMatch = existingAchievements.contains { $0.profile?.id == profile.id }
            if profileMatch {
                return  // Achievement already exists, avoid duplicate
            }
        }

        let achievement = Achievement(type: type)
        achievement.profile = profile
        if profile.achievements == nil {
            profile.achievements = []
        }
        profile.achievements?.append(achievement)
        modelContext.insert(achievement)

        // CRITICAL: Save immediately so achievement persists
        try? modelContext.save()
    }

    // MARK: - Stats Calculation

    func totalBooksRead() -> Int {
        // iOS 26 optimization: Add fetch limit for safety
        var descriptor = FetchDescriptor<Book>()
        descriptor.fetchLimit = 10000 // Sanity limit
        guard let books = try? modelContext.fetch(descriptor) else { return 0 }
        return books.filter { $0.readingStatus == .finished }.count
    }

    func totalPagesRead() -> Int {
        // ONLY count reading sessions (including auto-generated ones)
        // Auto-generated sessions now handle corrections with negative values
        // iOS 26 optimization: Add fetch limit for safety
        var sessionDescriptor = FetchDescriptor<ReadingSession>()
        sessionDescriptor.fetchLimit = 50000 // Sanity limit
        let sessionPages = (try? modelContext.fetch(sessionDescriptor))?
            .filter { $0.countsTowardStats }
            .reduce(0) { $0 + $1.pagesRead } ?? 0

        return max(0, sessionPages) // Don't show negative if user makes big corrections
    }

    func totalReadingMinutes() -> Int {
        // iOS 26 optimization: Add fetch limit for safety
        var descriptor = FetchDescriptor<ReadingSession>()
        descriptor.fetchLimit = 50000 // Sanity limit
        guard let sessions = try? modelContext.fetch(descriptor) else { return 0 }
        return sessions.filter { $0.countsTowardStats }.reduce(0) { $0 + $1.durationMinutes }
    }

    func booksReadThisYear() -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        // iOS 26 optimization: Add fetch limit for safety
        var descriptor = FetchDescriptor<Book>()
        descriptor.fetchLimit = 10000 // Sanity limit
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

        // iOS 26 optimization: Add fetch limit for safety
        var descriptor = FetchDescriptor<Book>()
        descriptor.fetchLimit = 10000 // Sanity limit
        guard let books = try? modelContext.fetch(descriptor) else { return 0 }

        return books.filter { book in
            guard book.readingStatus == .finished,
                  let dateFinished = book.dateFinished else { return false }
            return calendar.component(.year, from: dateFinished) == year &&
                   calendar.component(.month, from: dateFinished) == month
        }.count
    }
}

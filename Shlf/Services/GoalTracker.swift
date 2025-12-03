//
//  GoalTracker.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData
import OSLog

@MainActor
class GoalTracker {
    let modelContext: ModelContext
    private static let logger = Logger(subsystem: "com.shlf.app", category: "GoalTracker")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updateGoals(for profile: UserProfile) {
        let activeGoals = (profile.readingGoals ?? []).filter { $0.isActive }

        for goal in activeGoals {
            // Skip goals that have ended (end date is in the past)
            // Users can manually mark them complete or delete them
            if goal.endDate < Date() {
                Self.logger.debug("⏭️ Skipping ended goal: \(goal.type.rawValue)")
                continue
            }

            let newValue = calculateProgress(for: goal, profile: profile)
            goal.currentValue = newValue

            // Auto-complete if target reached
            if newValue >= goal.targetValue {
                goal.isCompleted = true
            }
        }

        // SAVE THE CONTEXT SO CHANGES ARE PERSISTED
        try? modelContext.save()
    }

    private func calculateProgress(for goal: ReadingGoal, profile: UserProfile) -> Int {
        let calendar = Calendar.current

        switch goal.type {
        case .booksPerYear, .booksPerMonth:
            // Count books finished in the goal period
            let descriptor = FetchDescriptor<Book>()
            let allBooks = (try? modelContext.fetch(descriptor)) ?? []

            return allBooks.filter { book in
                book.readingStatus == .finished &&
                book.dateFinished != nil &&
                book.dateFinished! >= goal.startDate &&
                book.dateFinished! <= goal.endDate
            }.count

        case .pagesPerDay:
            // ONLY count pages from ReadingSessions during the goal period
            // This ensures we only track progress made AFTER the goal was created
            let sessionDescriptor = FetchDescriptor<ReadingSession>()
            let allSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

            let sessions = allSessions.filter { session in
                session.startDate >= goal.startDate &&
                session.startDate <= goal.endDate
            }

            let totalPages = sessions.reduce(0) { $0 + $1.pagesRead }

            // Calculate days elapsed, capping at goal end date if goal has ended
            let endPoint = min(Date(), goal.endDate)
            let daysElapsed = max(1, calendar.dateComponents([.day], from: goal.startDate, to: endPoint).day ?? 1)

            return totalPages / daysElapsed

        case .minutesPerDay:
            // Calculate average minutes per day in the goal period
            let sessionDescriptor = FetchDescriptor<ReadingSession>()
            let allSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

            let sessions = allSessions.filter { session in
                session.startDate >= goal.startDate &&
                session.startDate <= goal.endDate
            }

            let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }

            // Calculate days elapsed, capping at goal end date if goal has ended
            let endPoint = min(Date(), goal.endDate)
            let daysElapsed = max(1, calendar.dateComponents([.day], from: goal.startDate, to: endPoint).day ?? 1)

            return totalMinutes / daysElapsed

        case .readingStreak:
            // Calculate longest streak within the goal period
            // This ensures streak goals only count consecutive days within the goal's date range
            let sessionDescriptor = FetchDescriptor<ReadingSession>()
            let allSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []

            // Filter sessions within goal period
            let sessionsInPeriod = allSessions.filter { session in
                session.startDate >= goal.startDate &&
                session.startDate <= goal.endDate
            }

            guard !sessionsInPeriod.isEmpty else { return 0 }

            // Get unique reading days within period
            let readingDays = Set(sessionsInPeriod.map { calendar.startOfDay(for: $0.startDate) })
            let sortedDays = readingDays.sorted()

            // Calculate longest consecutive streak in this period
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
                        // Streak broken, record previous and restart
                        longestStreak = max(longestStreak, currentStreakCount)
                        currentStreakCount = 1
                    }
                }

                longestStreak = max(longestStreak, currentStreakCount)
            }

            return longestStreak
        }
    }
}

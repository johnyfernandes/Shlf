//
//  GoalTracker.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData

@MainActor
class GoalTracker {
    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func updateGoals(for profile: UserProfile) {
        let activeGoals = profile.readingGoals.filter { $0.isActive }

        for goal in activeGoals {
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
            let daysElapsed = max(1, calendar.dateComponents([.day], from: goal.startDate, to: Date()).day ?? 1)

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
            let daysElapsed = max(1, calendar.dateComponents([.day], from: goal.startDate, to: Date()).day ?? 1)

            return totalMinutes / daysElapsed

        case .readingStreak:
            // Use the current streak from profile
            return profile.currentStreak
        }
    }
}

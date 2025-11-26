//
//  UserProfile.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var totalXP: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastReadingDate: Date?
    var hasCompletedOnboarding: Bool
    var isProUser: Bool
    var cloudSyncEnabled: Bool

    // Book Detail Display Preferences
    var showDescription: Bool
    var showMetadata: Bool
    var showSubjects: Bool
    var showReadingHistory: Bool
    var showNotes: Bool

    // Metadata Field Preferences
    var showPublisher: Bool
    var showPublishedDate: Bool
    var showLanguage: Bool
    var showISBN: Bool
    var showReadingTime: Bool

    // Reading Progress Preferences
    var pageIncrementAmount: Int

    @Relationship(deleteRule: .cascade)
    var readingGoals: [ReadingGoal]

    @Relationship(deleteRule: .cascade)
    var achievements: [Achievement]

    init(
        id: UUID = UUID(),
        totalXP: Int = 0,
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        lastReadingDate: Date? = nil,
        hasCompletedOnboarding: Bool = false,
        isProUser: Bool = false,
        cloudSyncEnabled: Bool = false,
        showDescription: Bool = true,
        showMetadata: Bool = true,
        showSubjects: Bool = true,
        showReadingHistory: Bool = true,
        showNotes: Bool = true,
        showPublisher: Bool = true,
        showPublishedDate: Bool = true,
        showLanguage: Bool = true,
        showISBN: Bool = true,
        showReadingTime: Bool = true,
        pageIncrementAmount: Int = 1
    ) {
        self.id = id
        self.totalXP = totalXP
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastReadingDate = lastReadingDate
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isProUser = isProUser
        self.cloudSyncEnabled = cloudSyncEnabled
        self.showDescription = showDescription
        self.showMetadata = showMetadata
        self.showSubjects = showSubjects
        self.showReadingHistory = showReadingHistory
        self.showNotes = showNotes
        self.showPublisher = showPublisher
        self.showPublishedDate = showPublishedDate
        self.showLanguage = showLanguage
        self.showISBN = showISBN
        self.showReadingTime = showReadingTime
        self.pageIncrementAmount = pageIncrementAmount
        self.readingGoals = []
        self.achievements = []
    }

    var currentLevel: Int {
        // Simple level calculation: every 1000 XP = 1 level
        totalXP / 1000 + 1
    }

    var xpForNextLevel: Int {
        let nextLevel = currentLevel + 1
        return (nextLevel - 1) * 1000
    }

    var xpProgressInCurrentLevel: Int {
        totalXP % 1000
    }

    var xpProgressPercentage: Double {
        Double(xpProgressInCurrentLevel) / 1000.0 * 100
    }
}

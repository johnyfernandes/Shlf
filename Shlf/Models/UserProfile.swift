//
//  UserProfile.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class UserProfile {
    var id: UUID = UUID()
    var totalXP: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastReadingDate: Date?
    var hasCompletedOnboarding: Bool = false
    var isProUser: Bool = false
    var cloudSyncEnabled: Bool = false
    var themeColorRawValue: String = ThemeColor.blue.rawValue

    // Book Detail Display Preferences
    var showDescription: Bool = true
    var showMetadata: Bool = true
    var showSubjects: Bool = true
    var showReadingHistory: Bool = true
    var showNotes: Bool = true

    // Metadata Field Preferences
    var showPublisher: Bool = true
    var showPublishedDate: Bool = true
    var showLanguage: Bool = true
    var showISBN: Bool = true
    var showReadingTime: Bool = true

    // Reading Progress Preferences
    var pageIncrementAmount: Int = 1
    var useProgressSlider: Bool = false // false = stepper, true = slider
    var showSliderButtons: Bool = false // show +/- buttons with slider
    var useCircularProgressWatch: Bool = false // false = progress bar (default), true = circular
    var enableWatchPositionMarking: Bool = true // allow marking reading position from Watch

    // Session Display Preferences
    var hideAutoSessionsIPhone: Bool = false // hide quick +1/-1 sessions on iPhone
    var hideAutoSessionsWatch: Bool = false // hide quick +1/-1 sessions on Watch
    var showSettingsOnWatch: Bool = true

    // Active Session Management
    var autoEndSessionEnabled: Bool = true // Auto-end sessions after inactivity
    var autoEndSessionHours: Int = 24 // Hours of inactivity before auto-end (default 24h)

    // Home Card Preferences
    var homeCardOrder: [String] = [
        StatCardType.currentStreak.rawValue,
        StatCardType.level.rawValue,
        StatCardType.booksRead.rawValue
    ]

    @Relationship(deleteRule: .cascade, inverse: \ReadingGoal.profile)
    var readingGoals: [ReadingGoal]?

    @Relationship(deleteRule: .cascade, inverse: \Achievement.profile)
    var achievements: [Achievement]?

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
        pageIncrementAmount: Int = 1,
        useProgressSlider: Bool = false,
        showSliderButtons: Bool = false,
        useCircularProgressWatch: Bool = false,
        hideAutoSessionsIPhone: Bool = false,
        hideAutoSessionsWatch: Bool = false,
        showSettingsOnWatch: Bool = true,
        homeCardOrder: [String] = [
            StatCardType.currentStreak.rawValue,
            StatCardType.level.rawValue,
            StatCardType.booksRead.rawValue
        ]
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
        self.useProgressSlider = useProgressSlider
        self.showSliderButtons = showSliderButtons
        self.useCircularProgressWatch = useCircularProgressWatch
        self.hideAutoSessionsIPhone = hideAutoSessionsIPhone
        self.hideAutoSessionsWatch = hideAutoSessionsWatch
        self.showSettingsOnWatch = showSettingsOnWatch
        self.homeCardOrder = homeCardOrder
        self.readingGoals = nil
        self.achievements = nil
    }

    // Helper computed property to get StatCardType array from strings
    var homeCards: [StatCardType] {
        homeCardOrder.compactMap { StatCardType(rawValue: $0) }
    }

    // Helper methods for managing home cards
    func addHomeCard(_ card: StatCardType) {
        if !homeCardOrder.contains(card.rawValue) {
            homeCardOrder.append(card.rawValue)
        }
    }

    func removeHomeCard(_ card: StatCardType) {
        homeCardOrder.removeAll { $0 == card.rawValue }
    }

    func moveHomeCard(from source: IndexSet, to destination: Int) {
        homeCardOrder.move(fromOffsets: source, toOffset: destination)
    }

    // Theme color computed property
    var themeColor: ThemeColor {
        get {
            ThemeColor(rawValue: themeColorRawValue) ?? .blue
        }
        set {
            themeColorRawValue = newValue.rawValue
        }
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

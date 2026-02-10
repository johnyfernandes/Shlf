//
//  Achievement.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Achievement {
    var id: UUID = UUID()
    var typeRawValue: String = AchievementType.firstBook.rawValue
    var unlockedAt: Date = Date()
    var isNew: Bool = true
    var profile: UserProfile?

    var type: AchievementType {
        get { AchievementType(rawValue: typeRawValue) ?? .firstBook }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        type: AchievementType,
        unlockedAt: Date = Date(),
        isNew: Bool = true
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.unlockedAt = unlockedAt
        self.isNew = isNew
    }
}

enum AchievementType: String, Codable, CaseIterable {
    // Reading milestones
    case firstBook = "First Book"
    case tenBooks = "10 Books"
    case fiftyBooks = "50 Books"
    case hundredBooks = "100 Books"

    // Page milestones
    case hundredPages = "100 Pages"
    case thousandPages = "1,000 Pages"
    case tenThousandPages = "10,000 Pages"

    // Streak milestones
    case sevenDayStreak = "7-Day Streak"
    case thirtyDayStreak = "30-Day Streak"
    case hundredDayStreak = "100-Day Streak"

    // Level milestones
    case levelFive = "Level 5"
    case levelTen = "Level 10"
    case levelTwenty = "Level 20"

    // Speed reading
    case hundredPagesInDay = "100 Pages in a Day"
    case marathonReader = "Marathon Reader"

    var nameKey: LocalizedStringKey {
        switch self {
        case .firstBook: return "Chapter One"
        case .tenBooks: return "Shelf Stacker"
        case .fiftyBooks: return "Library Builder"
        case .hundredBooks: return "Archive Legend"
        case .hundredPages: return "Page Turner"
        case .thousandPages: return "Page Voyager"
        case .tenThousandPages: return "Page Titan"
        case .sevenDayStreak: return "Weekly Flame"
        case .thirtyDayStreak: return "Monthly Blaze"
        case .hundredDayStreak: return "Iron Streak"
        case .levelFive: return "Rising Reader"
        case .levelTen: return "Seasoned Reader"
        case .levelTwenty: return "Master Reader"
        case .hundredPagesInDay: return "Century Sprint"
        case .marathonReader: return "Long Haul"
        }
    }

    var localizedName: String {
        switch self {
        case .firstBook:
            return String(localized: "Chapter One")
        case .tenBooks:
            return String(localized: "Shelf Stacker")
        case .fiftyBooks:
            return String(localized: "Library Builder")
        case .hundredBooks:
            return String(localized: "Archive Legend")
        case .hundredPages:
            return String(localized: "Page Turner")
        case .thousandPages:
            return String(localized: "Page Voyager")
        case .tenThousandPages:
            return String(localized: "Page Titan")
        case .sevenDayStreak:
            return String(localized: "Weekly Flame")
        case .thirtyDayStreak:
            return String(localized: "Monthly Blaze")
        case .hundredDayStreak:
            return String(localized: "Iron Streak")
        case .levelFive:
            return String(localized: "Rising Reader")
        case .levelTen:
            return String(localized: "Seasoned Reader")
        case .levelTwenty:
            return String(localized: "Master Reader")
        case .hundredPagesInDay:
            return String(localized: "Century Sprint")
        case .marathonReader:
            return String(localized: "Long Haul")
        }
    }

    func localizedName(locale: Locale) -> String {
        switch self {
        case .firstBook:
            return localized("Chapter One", locale: locale)
        case .tenBooks:
            return localized("Shelf Stacker", locale: locale)
        case .fiftyBooks:
            return localized("Library Builder", locale: locale)
        case .hundredBooks:
            return localized("Archive Legend", locale: locale)
        case .hundredPages:
            return localized("Page Turner", locale: locale)
        case .thousandPages:
            return localized("Page Voyager", locale: locale)
        case .tenThousandPages:
            return localized("Page Titan", locale: locale)
        case .sevenDayStreak:
            return localized("Weekly Flame", locale: locale)
        case .thirtyDayStreak:
            return localized("Monthly Blaze", locale: locale)
        case .hundredDayStreak:
            return localized("Iron Streak", locale: locale)
        case .levelFive:
            return localized("Rising Reader", locale: locale)
        case .levelTen:
            return localized("Seasoned Reader", locale: locale)
        case .levelTwenty:
            return localized("Master Reader", locale: locale)
        case .hundredPagesInDay:
            return localized("Century Sprint", locale: locale)
        case .marathonReader:
            return localized("Long Haul", locale: locale)
        }
    }

    var titleKey: LocalizedStringKey {
        nameKey
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .firstBook: return "First Book"
        case .tenBooks: return "10 Books"
        case .fiftyBooks: return "50 Books"
        case .hundredBooks: return "100 Books"
        case .hundredPages: return "100 Pages"
        case .thousandPages: return "1,000 Pages"
        case .tenThousandPages: return "10,000 Pages"
        case .sevenDayStreak: return "7-Day Streak"
        case .thirtyDayStreak: return "30-Day Streak"
        case .hundredDayStreak: return "100-Day Streak"
        case .levelFive: return "Level 5"
        case .levelTen: return "Level 10"
        case .levelTwenty: return "Level 20"
        case .hundredPagesInDay: return "100 Pages in a Day"
        case .marathonReader: return "Marathon Reader"
        }
    }

    var icon: String {
        switch self {
        case .firstBook, .tenBooks, .fiftyBooks, .hundredBooks:
            return "books.vertical.fill"
        case .hundredPages, .thousandPages, .tenThousandPages:
            return "doc.text.fill"
        case .sevenDayStreak, .thirtyDayStreak, .hundredDayStreak:
            return "flame.fill"
        case .levelFive, .levelTen, .levelTwenty:
            return "star.fill"
        case .hundredPagesInDay:
            return "bolt.fill"
        case .marathonReader:
            return "trophy.fill"
        }
    }

    var isRepeatable: Bool {
        switch self {
        case .hundredPagesInDay, .marathonReader:
            return true
        default:
            return false
        }
    }

    var isStreakAchievement: Bool {
        switch self {
        case .sevenDayStreak, .thirtyDayStreak, .hundredDayStreak:
            return true
        default:
            return false
        }
    }
}

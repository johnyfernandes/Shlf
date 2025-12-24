//
//  Achievement.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData

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

    var name: String {
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

    var title: String {
        name
    }

    var description: String {
        rawValue
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
}

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

    var title: String {
        rawValue
    }

    var description: String {
        switch self {
        case .firstBook: return "Finished your first book"
        case .tenBooks: return "Finished 10 books"
        case .fiftyBooks: return "Finished 50 books"
        case .hundredBooks: return "Finished 100 books"
        case .hundredPages: return "Read 100 pages total"
        case .thousandPages: return "Read 1,000 pages total"
        case .tenThousandPages: return "Read 10,000 pages total"
        case .sevenDayStreak: return "Read for 7 days in a row"
        case .thirtyDayStreak: return "Read for 30 days in a row"
        case .hundredDayStreak: return "Read for 100 days in a row"
        case .levelFive: return "Reached level 5"
        case .levelTen: return "Reached level 10"
        case .levelTwenty: return "Reached level 20"
        case .hundredPagesInDay: return "Read 100 pages in one day"
        case .marathonReader: return "Read for 3+ hours in one session"
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
}

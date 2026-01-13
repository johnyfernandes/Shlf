//
//  ReadingGoal.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class ReadingGoal {
    var id: UUID = UUID()
    var typeRawValue: String = GoalType.booksPerYear.rawValue
    var targetValue: Int = 0
    var currentValue: Int = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
    var isCompleted: Bool = false
    var createdAt: Date = Date()
    var profile: UserProfile?

    var type: GoalType {
        get { GoalType(rawValue: typeRawValue) ?? .booksPerYear }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        type: GoalType,
        targetValue: Int,
        currentValue: Int = 0,
        startDate: Date = Date(),
        endDate: Date,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.typeRawValue = type.rawValue
        self.targetValue = targetValue
        self.currentValue = currentValue
        self.startDate = startDate
        self.endDate = endDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }

    var progressPercentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(100, Double(currentValue) / Double(targetValue) * 100)
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate && !isCompleted
    }
}

enum GoalType: String, Codable, CaseIterable {
    case booksPerYear = "Books Per Year"
    case booksPerMonth = "Books Per Month"
    case pagesPerDay = "Pages Per Day"
    case minutesPerDay = "Minutes Per Day"
    case readingStreak = "Reading Streak"

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .booksPerYear: return "Books Per Year"
        case .booksPerMonth: return "Books Per Month"
        case .pagesPerDay: return "Pages Per Day"
        case .minutesPerDay: return "Minutes Per Day"
        case .readingStreak: return "Reading Streak"
        }
    }

    var icon: String {
        switch self {
        case .booksPerYear, .booksPerMonth: return "books.vertical"
        case .pagesPerDay: return "doc.text"
        case .minutesPerDay: return "clock"
        case .readingStreak: return "flame"
        }
    }

    var unitText: String {
        switch self {
        case .booksPerYear, .booksPerMonth:
            return String(localized: "books")
        case .pagesPerDay:
            return String(localized: "pages")
        case .minutesPerDay:
            return String(localized: "minutes")
        case .readingStreak:
            return String(localized: "days")
        }
    }

    var isDaily: Bool {
        self == .pagesPerDay || self == .minutesPerDay
    }
}

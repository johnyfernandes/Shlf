//
//  ReadingGoal.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData

@Model
final class ReadingGoal {
    var id: UUID
    var type: GoalType
    var targetValue: Int
    var currentValue: Int
    var startDate: Date
    var endDate: Date
    var isCompleted: Bool
    var createdAt: Date

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
        self.type = type
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

    var icon: String {
        switch self {
        case .booksPerYear, .booksPerMonth: return "books.vertical"
        case .pagesPerDay: return "doc.text"
        case .minutesPerDay: return "clock"
        case .readingStreak: return "flame"
        }
    }

    var unit: String {
        switch self {
        case .booksPerYear, .booksPerMonth: return "books"
        case .pagesPerDay: return "pages"
        case .minutesPerDay: return "minutes"
        case .readingStreak: return "days"
        }
    }
}

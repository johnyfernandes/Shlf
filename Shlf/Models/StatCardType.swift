//
//  StatCardType.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

enum StatCardType: String, Codable, CaseIterable, Identifiable {
    case currentStreak = "current_streak"
    case longestStreak = "longest_streak"
    case level = "level"
    case totalXP = "total_xp"
    case booksRead = "books_read"
    case pagesRead = "pages_read"
    case thisYear = "this_year"
    case thisMonth = "this_month"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentStreak: return "Streak"
        case .longestStreak: return "Best"
        case .level: return "Level"
        case .totalXP: return "XP"
        case .booksRead: return "Done"
        case .pagesRead: return "Pages"
        case .thisYear: return "Year"
        case .thisMonth: return "Month"
        }
    }

    var icon: String {
        switch self {
        case .currentStreak: return "flame.fill"
        case .longestStreak: return "flame.circle.fill"
        case .level: return "star.fill"
        case .totalXP: return "bolt.fill"
        case .booksRead: return "books.vertical.fill"
        case .pagesRead: return "doc.text.fill"
        case .thisYear: return "calendar"
        case .thisMonth: return "calendar.circle"
        }
    }

    #if os(iOS)
    var gradient: LinearGradient? {
        switch self {
        case .currentStreak, .longestStreak:
            return Theme.Colors.streakGradient
        case .level, .totalXP:
            return Theme.Colors.xpGradient
        case .booksRead:
            return Theme.Colors.successGradient
        case .pagesRead, .thisYear, .thisMonth:
            return nil
        }
    }
    #endif

    var displayName: String {
        switch self {
        case .currentStreak: return "Current Streak"
        case .longestStreak: return "Longest Streak"
        case .level: return "Level"
        case .totalXP: return "Total XP"
        case .booksRead: return "Books Read"
        case .pagesRead: return "Pages Read"
        case .thisYear: return "This Year"
        case .thisMonth: return "This Month"
        }
    }

    var description: String {
        switch self {
        case .currentStreak: return "Your current reading streak"
        case .longestStreak: return "Your longest reading streak"
        case .level: return "Your current level"
        case .totalXP: return "Total experience points earned"
        case .booksRead: return "Total books you've finished"
        case .pagesRead: return "Total pages you've read"
        case .thisYear: return "Books read this year"
        case .thisMonth: return "Books read this month"
        }
    }

    var isStreakCard: Bool {
        switch self {
        case .currentStreak, .longestStreak:
            return true
        default:
            return false
        }
    }
}

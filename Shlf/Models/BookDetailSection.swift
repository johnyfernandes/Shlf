//
//  BookDetailSection.swift
//  Shlf
//
//  Book detail page section types for customization
//

import SwiftUI

enum BookDetailSection: String, Codable, CaseIterable, Identifiable, Hashable {
    case bookStats = "Book Stats"
    case description = "Description"
    case lastPosition = "Last Position"
    case quotes = "Quotes"
    case notes = "Notes"
    case subjects = "Subjects"
    case metadata = "Metadata"
    case readingHistory = "Reading History"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bookStats: return "chart.bar.xaxis"
        case .description: return "text.alignleft"
        case .lastPosition: return "bookmark.fill"
        case .quotes: return "quote.bubble.fill"
        case .notes: return "note.text"
        case .subjects: return "tag.fill"
        case .metadata: return "info.circle.fill"
        case .readingHistory: return "clock.fill"
        }
    }

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .bookStats:
            return "Book Stats"
        case .description:
            return "Description"
        case .lastPosition:
            return "Last Position"
        case .quotes:
            return "Quotes"
        case .notes:
            return "Notes"
        case .subjects:
            return "Subjects"
        case .metadata:
            return "Metadata"
        case .readingHistory:
            return "Reading History"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .bookStats:
            return "Reading stats for this book"
        case .description:
            return "Book description and synopsis"
        case .lastPosition:
            return "Your last saved reading position"
        case .quotes:
            return "Saved quotes from this book"
        case .notes:
            return "Your personal notes"
        case .subjects:
            return "Book genres and categories"
        case .metadata:
            return "Publisher, ISBN, and other details"
        case .readingHistory:
            return "Your reading session history"
        }
    }
}

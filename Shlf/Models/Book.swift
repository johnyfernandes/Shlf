//
//  Book.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var author: String = ""
    var isbn: String?
    var coverImageURL: URL?
    var totalPages: Int?
    var currentPage: Int = 0
    var savedCurrentPage: Int? // Stores progress when switching away from Currently Reading
    var bookTypeRawValue: String = BookType.physical.rawValue
    var readingStatusRawValue: String = ReadingStatus.wantToRead.rawValue
    var dateAdded: Date = Date()
    var dateStarted: Date?
    var dateFinished: Date?
    var notes: String = ""
    var rating: Int?

    // Additional metadata
    var bookDescription: String?
    var subjects: [String]?
    var publisher: String?
    var publishedDate: String?
    var language: String?
    var openLibraryWorkID: String?
    var openLibraryEditionID: String?

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession]?

    @Relationship(deleteRule: .cascade, inverse: \BookPosition.book)
    var bookPositions: [BookPosition]?

    @Relationship(deleteRule: .cascade, inverse: \Quote.book)
    var quotes: [Quote]?

    @Relationship(deleteRule: .cascade, inverse: \ActiveReadingSession.book)
    var activeSessions: [ActiveReadingSession]?

    var bookType: BookType {
        get { BookType(rawValue: bookTypeRawValue) ?? .physical }
        set { bookTypeRawValue = newValue.rawValue }
    }

    var readingStatus: ReadingStatus {
        get { ReadingStatus(rawValue: readingStatusRawValue) ?? .wantToRead }
        set { readingStatusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        isbn: String? = nil,
        coverImageURL: URL? = nil,
        totalPages: Int? = nil,
        currentPage: Int = 0,
        bookType: BookType = .physical,
        readingStatus: ReadingStatus = .wantToRead,
        dateAdded: Date = Date(),
        dateStarted: Date? = nil,
        dateFinished: Date? = nil,
        notes: String = "",
        rating: Int? = nil,
        bookDescription: String? = nil,
        subjects: [String]? = nil,
        publisher: String? = nil,
        publishedDate: String? = nil,
        language: String? = nil,
        openLibraryWorkID: String? = nil,
        openLibraryEditionID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isbn = isbn
        self.coverImageURL = coverImageURL
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.bookTypeRawValue = bookType.rawValue
        self.readingStatusRawValue = readingStatus.rawValue
        self.dateAdded = dateAdded
        self.dateStarted = dateStarted
        self.dateFinished = dateFinished
        self.notes = notes
        self.rating = rating
        self.bookDescription = bookDescription
        self.subjects = subjects
        self.publisher = publisher
        self.publishedDate = publishedDate
        self.language = language
        self.openLibraryWorkID = openLibraryWorkID
        self.openLibraryEditionID = openLibraryEditionID
        self.readingSessions = nil
    }

    var progressPercentage: Double {
        guard let total = totalPages, total > 0 else { return 0 }
        // Clamp to [0, 100] to prevent overflow if currentPage > totalPages
        let percentage = Double(currentPage) / Double(total) * 100
        return min(100, max(0, percentage))
    }

    var isFinished: Bool {
        readingStatus == .finished
    }

    var lastPosition: BookPosition? {
        bookPositions?.sorted { $0.timestamp > $1.timestamp }.first
    }
}

enum BookType: String, Codable, CaseIterable {
    case physical = "Physical"
    case ebook = "Ebook"
    case audiobook = "Audiobook"

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .physical: return "Physical"
        case .ebook: return "Ebook"
        case .audiobook: return "Audiobook"
        }
    }

    var displayNameText: String {
        String(localized: displayNameKey)
    }

    var icon: String {
        switch self {
        case .physical: return "book.closed"
        case .ebook: return "ipad.and.iphone"
        case .audiobook: return "headphones"
        }
    }
}

enum ReadingStatus: String, Codable, CaseIterable {
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case finished = "Finished"
    case didNotFinish = "Did Not Finish"

    var displayNameKey: LocalizedStringKey {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .finished: return "Finished"
        case .didNotFinish: return "Did Not Finish"
        }
    }

    var icon: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .currentlyReading: return "book"
        case .finished: return "checkmark.circle.fill"
        case .didNotFinish: return "xmark.circle"
        }
    }

    var shortNameKey: LocalizedStringKey {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Reading"
        case .finished: return "Finished"
        case .didNotFinish: return "DNF"
        }
    }

    var shortNameText: String {
        String(localized: shortNameKey)
    }
}

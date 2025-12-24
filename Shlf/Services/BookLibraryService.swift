//
//  BookLibraryService.swift
//  Shlf
//
//  Created by Claude Code on 03/12/2025.
//

import Foundation
import SwiftData

/// Centralized service for managing book library operations
@MainActor
final class BookLibraryService {

    /// Result of duplicate check
    enum DuplicateCheckResult {
        case noDuplicate
        case duplicate(Book)
    }

    /// Check if a book already exists in the library
    /// - Parameters:
    ///   - title: Book title
    ///   - author: Book author
    ///   - isbn: Book ISBN (optional, but preferred for accurate matching)
    ///   - modelContext: SwiftData model context
    /// - Returns: DuplicateCheckResult indicating if duplicate exists
    static func checkForDuplicate(
        title: String,
        author: String,
        isbn: String?,
        in modelContext: ModelContext
    ) throws -> DuplicateCheckResult {

        // Primary check: ISBN-based (most accurate)
        if let isbn = isbn, !isbn.isEmpty {
            let isbnPredicate = #Predicate<Book> { book in
                book.isbn == isbn
            }
            let isbnDescriptor = FetchDescriptor<Book>(predicate: isbnPredicate)
            let isbnMatches = try modelContext.fetch(isbnDescriptor)

            if let existingBook = isbnMatches.first {
                return .duplicate(existingBook)
            }
        }

        // Fallback check: Title + Author (case-insensitive)
        // Fetch all books and filter in memory for case-insensitive comparison
        let allBooksDescriptor = FetchDescriptor<Book>()
        let allBooks = try modelContext.fetch(allBooksDescriptor)

        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAuthor = author.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let existingBook = allBooks.first { book in
            let bookTitle = book.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let bookAuthor = book.author.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return bookTitle == normalizedTitle && bookAuthor == normalizedAuthor
        }

        if let existingBook = existingBook {
            return .duplicate(existingBook)
        }

        return .noDuplicate
    }

    /// Add a book to the library with duplicate checking
    /// - Parameters:
    ///   - bookInfo: Book information to add
    ///   - bookType: Type of book
    ///   - readingStatus: Reading status
    ///   - currentPage: Current page (if reading)
    ///   - modelContext: SwiftData model context
    /// - Returns: Result with the book (new or existing) or error
    static func addBook(
        bookInfo: BookInfo,
        bookType: BookType,
        readingStatus: ReadingStatus,
        currentPage: Int,
        to modelContext: ModelContext
    ) throws -> Result<(book: Book, isDuplicate: Bool), Error> {

        // Check for duplicates first
        let duplicateCheck = try checkForDuplicate(
            title: bookInfo.title,
            author: bookInfo.author,
            isbn: bookInfo.isbn,
            in: modelContext
        )

        switch duplicateCheck {
        case .duplicate(let existingBook):
            return .success((existingBook, true))

        case .noDuplicate:
            let book = Book(
                title: bookInfo.title,
                author: bookInfo.author,
                isbn: bookInfo.isbn,
                coverImageURL: bookInfo.coverImageURL,
                totalPages: bookInfo.totalPages ?? 0,
                currentPage: readingStatus == .currentlyReading ? currentPage : 0,
                bookType: bookType,
                readingStatus: readingStatus,
                bookDescription: bookInfo.description,
                subjects: bookInfo.subjects,
                publisher: bookInfo.publisher,
                publishedDate: bookInfo.publishedDate,
                language: bookInfo.language,
                openLibraryWorkID: bookInfo.workID,
                openLibraryEditionID: bookInfo.olid
            )

            modelContext.insert(book)
            return .success((book, false))
        }
    }
}

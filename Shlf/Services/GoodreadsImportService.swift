//
//  GoodreadsImportService.swift
//  Shlf
//
//  Import books from Goodreads CSV export
//

#if os(iOS) && !WIDGET_EXTENSION
import Foundation
import SwiftData

enum GoodreadsImportError: LocalizedError {
    case emptyFile
    case missingRequiredColumns
    case unreadableFile

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return String(localized: "Goodreads CSV is empty.")
        case .missingRequiredColumns:
            return String(localized: "Goodreads CSV is missing a Title or Author column.")
        case .unreadableFile:
            return String(localized: "Could not read CSV file.")
        }
    }
}

struct GoodreadsImportOptions {
    var applyShelvesToStatus: Bool = true
    var importRatingsAndNotes: Bool = true
    var useDates: Bool = true
    var createImportedSessions: Bool = false
    var preferGoodreadsData: Bool = false
}

struct GoodreadsImportResult {
    let totalRows: Int
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let createdSessions: Int
    let reachedFreeLimit: Bool
}

struct GoodreadsImportProgress: Sendable {
    let current: Int
    let total: Int
    let title: String?
}

enum GoodreadsImportService {
    static func parse(data: Data) throws -> GoodreadsImportDocument {
        try GoodreadsCSVParser.parse(data: data)
    }

    @MainActor
    static func `import`(
        document: GoodreadsImportDocument,
        options: GoodreadsImportOptions,
        modelContext: ModelContext,
        isProUser: Bool,
        progress: ((GoodreadsImportProgress) -> Void)? = nil
    ) throws -> GoodreadsImportResult {
        var imported = 0
        var updated = 0
        var skipped = 0
        var createdSessions = 0
        var reachedLimit = false
        let totalRows = document.rows.count

        let existingCount = (try? modelContext.fetch(FetchDescriptor<Book>()).count) ?? 0
        var currentCount = existingCount

        for (index, row) in document.rows.enumerated() {
            let titleForProgress = row.value(for: ["title"])
            progress?(GoodreadsImportProgress(current: index + 1, total: totalRows, title: titleForProgress))

            if !isProUser && currentCount >= 5 {
                reachedLimit = true
                break
            }

            guard let title = row.value(for: ["title"]),
                  let author = row.value(for: ["author"]) else {
                skipped += 1
                continue
            }

            let isbn13 = sanitizeISBN(row.value(for: ["isbn13"]))
            let isbn10 = sanitizeISBN(row.value(for: ["isbn"]))
            let isbn = isbn13 ?? isbn10
            let publisher = row.value(for: ["publisher"])
            let binding = row.value(for: ["binding"])
            let pages = parseInt(row.value(for: ["number of pages"]))
            let yearPublished = row.value(for: ["year published", "original publication year"])
            let dateRead = parseDate(row.value(for: ["date read"]))
            let dateAdded = parseDate(row.value(for: ["date added"]))
            let rating = parseInt(row.value(for: ["my rating"]))
            let review = row.value(for: ["my review"])
            let privateNotes = row.value(for: ["private notes"])

            let exclusiveShelf = row.value(for: ["exclusive shelf"])
            let shelves = GoodreadsCSVParser.parseShelfList(row.value(for: ["bookshelves"]))
            let customShelves = filterCustomShelves(shelves, exclusiveShelf: exclusiveShelf)
            let status = options.applyShelvesToStatus
                ? resolveStatus(exclusiveShelf: exclusiveShelf, shelves: shelves)
                : .wantToRead

            let bookType = resolveBookType(binding)

            let duplicateCheck = try BookLibraryService.checkForDuplicate(
                title: title,
                author: author,
                isbn: isbn,
                in: modelContext
            )

            switch duplicateCheck {
            case .duplicate(let existingBook):
                let didUpdate = updateExistingBook(
                    existingBook,
                    title: title,
                    author: author,
                    isbn: isbn,
                    publisher: publisher,
                    pages: pages,
                    yearPublished: yearPublished,
                    rating: rating,
                    review: review,
                    privateNotes: privateNotes,
                    dateAdded: dateAdded,
                    dateRead: dateRead,
                    status: status,
                    bookType: bookType,
                    shelves: customShelves,
                    options: options
                )

                if didUpdate {
                    updated += 1
                } else {
                    skipped += 1
                }

            case .noDuplicate:
                let maxPages = pages ?? 0
                let currentPage = status == .finished ? maxPages : 0
                let book = Book(
                    title: title,
                    author: author,
                    isbn: isbn,
                    totalPages: pages,
                    currentPage: currentPage,
                    bookType: bookType,
                    readingStatus: status,
                    goodreadsShelves: customShelves.isEmpty ? nil : customShelves
                )

                if let publisher, !publisher.isEmpty {
                    book.publisher = publisher
                }
                if let yearPublished, !yearPublished.isEmpty {
                    book.publishedDate = yearPublished
                }
                if options.importRatingsAndNotes, let rating, rating > 0 {
                    book.rating = rating
                }
                if options.importRatingsAndNotes {
                    let noteText = combineNotes(privateNotes: privateNotes, review: review)
                    if let noteText, !noteText.isEmpty {
                        book.notes = noteText
                    }
                }
                if options.useDates {
                    if let dateAdded {
                        book.dateAdded = dateAdded
                        if status != .wantToRead {
                            book.dateStarted = dateAdded
                        }
                    }
                    if status == .finished {
                        if let dateRead {
                            book.dateFinished = dateRead
                        } else if let dateAdded {
                            book.dateFinished = dateAdded
                        }
                    }
                } else if status == .finished {
                    if let dateRead {
                        book.dateFinished = dateRead
                    } else if let dateAdded {
                        book.dateFinished = dateAdded
                    }
                }

                modelContext.insert(book)
                imported += 1
                currentCount += 1

                if options.createImportedSessions, status == .finished {
                    let finishedDate = dateRead ?? Date()
                    let endPage = book.totalPages ?? 0
                    let session = ReadingSession(
                        startDate: finishedDate,
                        endDate: finishedDate,
                        startPage: 0,
                        endPage: endPage,
                        durationMinutes: 0,
                        xpEarned: 0,
                        isAutoGenerated: false,
                        countsTowardStats: false,
                        isImported: true,
                        book: book
                    )
                    modelContext.insert(session)
                    createdSessions += 1
                }
            }
        }

        try modelContext.save()

        return GoodreadsImportResult(
            totalRows: document.rows.count,
            importedCount: imported,
            updatedCount: updated,
            skippedCount: skipped,
            createdSessions: createdSessions,
            reachedFreeLimit: reachedLimit
        )
    }

    private static func updateExistingBook(
        _ book: Book,
        title: String,
        author: String,
        isbn: String?,
        publisher: String?,
        pages: Int?,
        yearPublished: String?,
        rating: Int?,
        review: String?,
        privateNotes: String?,
        dateAdded: Date?,
        dateRead: Date?,
        status: ReadingStatus,
        bookType: BookType,
        shelves: [String],
        options: GoodreadsImportOptions
    ) -> Bool {
        var didUpdate = false
        let preferGoodreads = options.preferGoodreadsData

        if book.title.isEmpty {
            book.title = title
            didUpdate = true
        }
        if book.author.isEmpty {
            book.author = author
            didUpdate = true
        }
        if book.isbn == nil, let isbn {
            book.isbn = isbn
            didUpdate = true
        }
        if book.publisher == nil, let publisher {
            book.publisher = publisher
            didUpdate = true
        }
        if book.totalPages == nil, let pages {
            book.totalPages = pages
            didUpdate = true
        }
        if book.publishedDate == nil, let yearPublished {
            book.publishedDate = yearPublished
            didUpdate = true
        }

        if !shelves.isEmpty, preferGoodreads || book.goodreadsShelves == nil {
            book.goodreadsShelves = shelves
            didUpdate = true
        }

        if preferGoodreads, book.bookType != bookType {
            book.bookType = bookType
            didUpdate = true
        }

        if options.importRatingsAndNotes {
            if let rating, rating > 0, (preferGoodreads || book.rating == nil) {
                book.rating = rating
                didUpdate = true
            }

            let noteText = combineNotes(privateNotes: privateNotes, review: review)
            if let noteText, !noteText.isEmpty, (preferGoodreads || book.notes.isEmpty) {
                book.notes = noteText
                didUpdate = true
            }
        }

        if options.useDates {
            if preferGoodreads, let dateAdded {
                book.dateAdded = dateAdded
                didUpdate = true
            }

            if status == .finished {
                if preferGoodreads || book.dateFinished == nil {
                    if let finishedDate = dateRead ?? dateAdded {
                        book.dateFinished = finishedDate
                        didUpdate = true
                    }
                }
            } else if preferGoodreads, let dateAdded, book.dateStarted == nil {
                book.dateStarted = dateAdded
                didUpdate = true
            }
        }

        if options.applyShelvesToStatus, preferGoodreads, book.readingStatus != status {
            book.readingStatus = status
            didUpdate = true

            if status == .finished, let pages = pages ?? book.totalPages {
                book.currentPage = pages
                didUpdate = true
            }
        }

        return didUpdate
    }

    private static func resolveStatus(exclusiveShelf: String?, shelves: [String]) -> ReadingStatus {
        if let shelf = statusFromShelf(exclusiveShelf) {
            return shelf
        }

        let shelfList = shelves.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        for candidate in ["dnf", "did-not-finish", "did not finish"] {
            if shelfList.contains(candidate) {
                return .didNotFinish
            }
        }
        if shelfList.contains("currently-reading") {
            return .currentlyReading
        }
        if shelfList.contains("read") {
            return .finished
        }
        if shelfList.contains("to-read") || shelfList.contains("want-to-read") {
            return .wantToRead
        }

        return .wantToRead
    }

    private static func filterCustomShelves(_ shelves: [String], exclusiveShelf: String?) -> [String] {
        let exclusiveLower = exclusiveShelf?.lowercased()
        let reserved: Set<String> = [
            "read",
            "currently-reading",
            "to-read",
            "want-to-read",
            "dnf",
            "did-not-finish",
            "did not finish"
        ]

        var uniqueShelves: [String] = []
        for shelf in shelves {
            let trimmed = shelf.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            if let exclusiveLower, lower == exclusiveLower { continue }
            if reserved.contains(lower) { continue }
            if uniqueShelves.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) { continue }
            uniqueShelves.append(trimmed)
        }
        return uniqueShelves
    }

    private static func statusFromShelf(_ shelf: String?) -> ReadingStatus? {
        guard let shelf = shelf?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !shelf.isEmpty else {
            return nil
        }

        switch shelf {
        case "read": return .finished
        case "currently-reading": return .currentlyReading
        case "to-read", "want-to-read": return .wantToRead
        case "dnf", "did-not-finish", "did not finish": return .didNotFinish
        default:
            return nil
        }
    }

    private static func resolveBookType(_ binding: String?) -> BookType {
        let normalized = binding?.lowercased() ?? ""
        if normalized.contains("audio") {
            return .audiobook
        }
        if normalized.contains("kindle") || normalized.contains("ebook") || normalized.contains("e-book") {
            return .ebook
        }
        return .physical
    }

    private static func combineNotes(privateNotes: String?, review: String?) -> String? {
        let notes = [privateNotes, review]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !notes.isEmpty else { return nil }
        return notes.joined(separator: "\n\n")
    }

    private static func sanitizeISBN(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = value.uppercased().filter { $0.isNumber || $0 == "X" }
        return sanitized.isEmpty ? nil : sanitized
    }

    private static func parseInt(_ value: String?) -> Int? {
        guard let value else { return nil }
        let digits = value.filter { $0.isNumber }
        return Int(digits)
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        for formatter in dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }


    private static let dateFormatters: [DateFormatter] = {
        let formats = [
            "yyyy/MM/dd",
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "dd/MM/yyyy",
            "MMM d, yyyy"
        ]

        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            return formatter
        }
    }()
}
#endif

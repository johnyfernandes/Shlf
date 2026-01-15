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
    var createImportedSessions: Bool = true
    var preferGoodreadsData: Bool = false
}

struct GoodreadsImportResult {
    let totalRows: Int
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let createdSessions: Int
    let reachedFreeLimit: Bool
    let booksNeedingDescriptions: [Book]
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
    static func duplicateCount(
        document: GoodreadsImportDocument,
        modelContext: ModelContext
    ) throws -> Int {
        let existingBooks = try modelContext.fetch(FetchDescriptor<Book>())
        var isbnIndex = Set<String>()
        var titleAuthorIndex = Set<String>()

        for book in existingBooks {
            if let isbn = sanitizeISBN(book.isbn) {
                isbnIndex.insert(isbn)
            }
            let titleKey = normalizeKey(book.title)
            let authorKey = normalizeKey(book.author)
            if !titleKey.isEmpty, !authorKey.isEmpty {
                titleAuthorIndex.insert("\(titleKey)|\(authorKey)")
            }
        }

        var matchedKeys = Set<String>()
        var duplicates = 0

        for row in document.rows {
            guard let title = row.value(for: ["title"]),
                  let author = row.value(for: ["author"]) else {
                continue
            }

            let isbn = sanitizeISBN(row.value(for: ["isbn13"])) ?? sanitizeISBN(row.value(for: ["isbn"]))
            let titleKey = normalizeKey(title)
            let authorKey = normalizeKey(author)
            let titleAuthorKey = (!titleKey.isEmpty && !authorKey.isEmpty) ? "\(titleKey)|\(authorKey)" : nil

            let matchKey = isbn ?? titleAuthorKey
            guard let matchKey else { continue }
            if matchedKeys.contains(matchKey) { continue }

            if let isbn, isbnIndex.contains(isbn) {
                duplicates += 1
                matchedKeys.insert(matchKey)
                continue
            }

            if let titleAuthorKey, titleAuthorIndex.contains(titleAuthorKey) {
                duplicates += 1
                matchedKeys.insert(matchKey)
            }
        }

        return duplicates
    }

    @MainActor
    static func `import`(
        document: GoodreadsImportDocument,
        options: GoodreadsImportOptions,
        modelContext: ModelContext,
        isProUser: Bool,
        progress: ((GoodreadsImportProgress) -> Void)? = nil
    ) async throws -> GoodreadsImportResult {
        var imported = 0
        var updated = 0
        var skipped = 0
        var createdSessions = 0
        var reachedLimit = false
        var booksNeedingDescriptions: [Book] = []
        var descriptionCandidateIDs = Set<UUID>()
        let totalRows = document.rows.count
        let bookAPI = BookAPIService()
        let coverCache = CoverCache()

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

                let coverURL = await resolveCoverURL(
                    isbn: isbn,
                    title: title,
                    author: author,
                    bookAPI: bookAPI,
                    cache: coverCache
                )

                var didUpdateWithCover = didUpdate
                if existingBook.coverImageURL == nil, let coverURL {
                    existingBook.coverImageURL = coverURL
                    didUpdateWithCover = true
                }

                if didUpdateWithCover {
                    updated += 1
                } else {
                    skipped += 1
                }
                if needsDescription(existingBook), descriptionCandidateIDs.insert(existingBook.id).inserted {
                    booksNeedingDescriptions.append(existingBook)
                }

            case .noDuplicate:
                let coverURL = await resolveCoverURL(
                    isbn: isbn,
                    title: title,
                    author: author,
                    bookAPI: bookAPI,
                    cache: coverCache
                )
                let maxPages = pages ?? 0
                let currentPage = status == .finished ? maxPages : 0
                let book = Book(
                    title: title,
                    author: author,
                    isbn: isbn,
                    coverImageURL: coverURL,
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
                if needsDescription(book), descriptionCandidateIDs.insert(book.id).inserted {
                    booksNeedingDescriptions.append(book)
                }

                if options.createImportedSessions, status == .finished {
                    if let finishedDate = dateRead ?? dateAdded,
                       let endPage = book.totalPages,
                       endPage > 0 {
                        let session = ReadingSession(
                            startDate: finishedDate,
                            endDate: finishedDate,
                            startPage: 0,
                            endPage: endPage,
                            durationMinutes: 0,
                            xpEarned: 0,
                            isAutoGenerated: true,
                            countsTowardStats: false,
                            isImported: true,
                            book: book
                        )
                        modelContext.insert(session)
                        createdSessions += 1
                    }
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
            reachedFreeLimit: reachedLimit,
            booksNeedingDescriptions: booksNeedingDescriptions
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

        for shelf in shelves {
            if let status = statusFromShelf(shelf) {
                return status
            }
        }

        return .wantToRead
    }

    private static func filterCustomShelves(_ shelves: [String], exclusiveShelf: String?) -> [String] {
        var uniqueShelves: [String] = []
        for shelf in shelves {
            let trimmed = shelf.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if isDefaultShelf(trimmed, exclusiveShelf: exclusiveShelf) { continue }
            if uniqueShelves.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) { continue }
            uniqueShelves.append(trimmed)
        }
        return uniqueShelves
    }

    private static func isDefaultShelf(_ shelf: String, exclusiveShelf: String?) -> Bool {
        let lower = shelf.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lower.isEmpty else { return true }
        if let exclusiveLower = exclusiveShelf?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           lower == exclusiveLower {
            return true
        }

        let reserved = [
            "read",
            "currently-reading",
            "currently reading",
            "to-read",
            "to read",
            "want-to-read",
            "want to read",
            "dnf",
            "did-not-finish",
            "did not finish"
        ]

        for key in reserved {
            if lower == key { return true }
            if lower.hasPrefix(key + " ") ||
                lower.hasPrefix(key + "(") ||
                lower.hasPrefix(key + " (") ||
                lower.hasPrefix(key + " #") ||
                lower.hasPrefix(key + " (#") {
                return true
            }
        }
        return false
    }

    private static func statusFromShelf(_ shelf: String?) -> ReadingStatus? {
        guard let shelf = shelf?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !shelf.isEmpty else {
            return nil
        }

        let normalized = shelf.replacingOccurrences(of: " ", with: "-")

        if normalized.hasPrefix("read") {
            return .finished
        }
        if normalized.hasPrefix("currently-reading") {
            return .currentlyReading
        }
        if normalized.hasPrefix("to-read") || normalized.hasPrefix("want-to-read") {
            return .wantToRead
        }
        if normalized.hasPrefix("dnf") || normalized.hasPrefix("did-not-finish") {
            return .didNotFinish
        }

        return nil
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

    private static func needsDescription(_ book: Book) -> Bool {
        book.bookDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }

    @MainActor
    static func enrichDescriptions(
        books: [Book],
        modelContext: ModelContext,
        progress: ((Int, Int, String?) -> Void)? = nil
    ) async {
        guard !books.isEmpty else { return }
        let bookAPI = BookAPIService()
        var workCache: [String: String] = [:]
        var missingWorkDescriptions: Set<String> = []
        var editionCache: [String: EditionDetails] = [:]
        var missingEditions: Set<String> = []
        let total = books.count
        var index = 0

        for book in books {
            index += 1
            progress?(index, total, book.title)

            guard needsDescription(book) else { continue }

            let normalizedISBN = sanitizeISBN(book.isbn)
            var workID: String? = book.openLibraryWorkID

            if let normalizedISBN {
                if editionCache[normalizedISBN] == nil, !missingEditions.contains(normalizedISBN) {
                    if let fetched = try? await bookAPI.fetchEditionDetails(isbn: normalizedISBN) {
                        editionCache[normalizedISBN] = fetched
                    } else {
                        missingEditions.insert(normalizedISBN)
                    }
                }
                if let editionDetails = editionCache[normalizedISBN] {
                    if let text = firstNonEmpty(editionDetails.description, editionDetails.notes, editionDetails.firstSentence) {
                        book.bookDescription = text
                    }
                    if workID == nil {
                        workID = editionDetails.workID
                    }
                }
            }

            if needsDescription(book), let workID {
                if workCache[workID] == nil, !missingWorkDescriptions.contains(workID) {
                    let workDetails = try? await bookAPI.fetchWorkDetails(workID: workID)
                    if let description = workDetails?.description {
                        workCache[workID] = description
                    } else {
                        missingWorkDescriptions.insert(workID)
                    }
                }
                if let description = workCache[workID],
                   !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    book.bookDescription = description
                }
            }

            if book.openLibraryWorkID == nil, let workID {
                book.openLibraryWorkID = workID
            }
        }

        try? modelContext.save()
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
               !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static func resolveCoverURL(
        isbn: String?,
        title: String,
        author: String,
        bookAPI: BookAPIService,
        cache: CoverCache
    ) async -> URL? {
        let normalizedISBN = sanitizeISBN(isbn)
        let titleKey = normalizeKey(title)
        let authorKey = normalizeKey(author)

        if let normalizedISBN {
            let cacheKey = "isbn:\(normalizedISBN)"
            if let cached = cache.values[cacheKey] {
                return cached.value
            }

            if let bookInfo = try? await bookAPI.fetchBook(isbn: normalizedISBN),
               let coverURL = bookInfo.coverImageURL {
                cache.values[cacheKey] = .found(coverURL)
                return coverURL
            }

            cache.values[cacheKey] = .missing
        }

        if !titleKey.isEmpty, !authorKey.isEmpty {
            let cacheKey = "title:\(titleKey)|\(authorKey)"
            if let cached = cache.values[cacheKey] {
                return cached.value
            }

            let query = "\(title) \(author)"
            if let match = try? await bookAPI.searchBooks(query: query).first(where: { $0.coverImageURL != nil }),
               let coverURL = match.coverImageURL {
                cache.values[cacheKey] = .found(coverURL)
                return coverURL
            }

            cache.values[cacheKey] = .missing
        }

        return nil
    }

    private enum CoverLookup {
        case found(URL)
        case missing

        var value: URL? {
            switch self {
            case .found(let url): return url
            case .missing: return nil
            }
        }
    }

    private final class CoverCache {
        var values: [String: CoverLookup] = [:]
    }

    private static func sanitizeISBN(_ value: String?) -> String? {
        guard let value else { return nil }
        let sanitized = value.uppercased().filter { $0.isNumber || $0 == "X" }
        return sanitized.isEmpty ? nil : sanitized
    }

    private static func normalizeKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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

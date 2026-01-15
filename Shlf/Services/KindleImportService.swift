//
//  KindleImportService.swift
//  Shlf
//
//  Import Kindle library items into the app
//

#if os(iOS) && !WIDGET_EXTENSION
import Foundation
import SwiftData

struct KindleImportItem: Codable, Hashable {
    let asin: String?
    let title: String
    let author: String
    let coverURL: String?
    let isSample: Bool
}

struct KindleImportResult {
    let totalItems: Int
    let importedCount: Int
    let skippedCount: Int
    let reachedFreeLimit: Bool
}

struct KindleImportProgress: Sendable {
    let current: Int
    let total: Int
    let title: String?
}

enum KindleImportService {
    @MainActor
    static func `import`(
        items: [KindleImportItem],
        modelContext: ModelContext,
        isProUser: Bool,
        progress: ((KindleImportProgress) -> Void)? = nil
    ) async throws -> KindleImportResult {
        var imported = 0
        var skipped = 0
        var reachedLimit = false
        let total = items.count

        let existingCount = (try? modelContext.fetch(FetchDescriptor<Book>()).count) ?? 0
        var currentCount = existingCount

        for (index, item) in items.enumerated() {
            progress?(KindleImportProgress(current: index + 1, total: total, title: item.title))

            if !isProUser && currentCount >= 5 {
                reachedLimit = true
                break
            }

            if item.isSample || item.title.isEmpty || item.author.isEmpty {
                skipped += 1
                continue
            }

            let duplicate = try BookLibraryService.checkForDuplicate(
                title: item.title,
                author: item.author,
                isbn: nil,
                in: modelContext
            )

            switch duplicate {
            case .duplicate:
                skipped += 1
                continue
            case .noDuplicate:
                let coverURL = item.coverURL.flatMap(URL.init(string:))
                let bookInfo = BookInfo(
                    title: item.title,
                    author: item.author,
                    isbn: nil,
                    coverImageURL: coverURL,
                    totalPages: nil,
                    publishedDate: nil,
                    description: nil,
                    subjects: nil,
                    publisher: nil,
                    language: nil,
                    olid: nil,
                    workID: nil
                )

                let result = try BookLibraryService.addBook(
                    bookInfo: bookInfo,
                    bookType: .ebook,
                    readingStatus: .wantToRead,
                    currentPage: 0,
                    to: modelContext
                )

                switch result {
                case .success(let payload):
                    if !payload.isDuplicate {
                        imported += 1
                        currentCount += 1
                    } else {
                        skipped += 1
                    }
                case .failure:
                    skipped += 1
                }
            }
        }

        try modelContext.save()

        return KindleImportResult(
            totalItems: total,
            importedCount: imported,
            skippedCount: skipped,
            reachedFreeLimit: reachedLimit
        )
    }
}
#endif

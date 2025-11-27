//
//  BookAPIService.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation

struct BookInfo: Hashable {
    let title: String
    let author: String
    let isbn: String?
    let coverImageURL: URL?
    let totalPages: Int?
    let publishedDate: String?
    let description: String?
    let subjects: [String]?
    let publisher: String?
    let language: String?
    let olid: String? // Open Library ID for fetching full details
    let workID: String? // Work ID for finding best edition
}

enum BookAPIError: Error {
    case networkError
    case invalidResponse
    case bookNotFound
    case invalidISBN

    var localizedDescription: String {
        switch self {
        case .networkError: return "Network connection failed"
        case .invalidResponse: return "Invalid response from server"
        case .bookNotFound: return "Book not found"
        case .invalidISBN: return "Invalid ISBN format"
        }
    }
}

@Observable
final class BookAPIService {
    private let urlSession: URLSession
    private let rateLimiter: RateLimiter
    private let retryPolicy: RetryPolicy

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.rateLimiter = RateLimiter(maxRequestsPerSecond: 5)
        self.retryPolicy = RetryPolicy(maxRetries: 3, baseDelay: 1.0)
    }

    // MARK: - Public API

    func fetchBook(isbn: String) async throws -> BookInfo {
        try await fetchFromOpenLibrary(isbn: isbn)
    }

    func fetchBookByOLID(olid: String) async throws -> BookInfo {
        try await fetchByOLID(olid: olid)
    }

    func searchBooks(query: String) async throws -> [BookInfo] {
        // Use Open Library for search
        try await searchOpenLibrary(query: query)
    }

    func findBestEdition(workID: String, originalTitle: String) async throws -> String? {
        try await fetchBestEditionOLID(workID: workID, originalTitle: originalTitle)
    }

    // MARK: - Open Library API

    private func fetchFromOpenLibrary(isbn: String) async throws -> BookInfo {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        let urlString = "https://openlibrary.org/api/books?bibkeys=ISBN:\(cleanISBN)&format=json&jscmd=data"

        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidISBN
        }

        await rateLimiter.waitForToken()
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookData = json["ISBN:\(cleanISBN)"] as? [String: Any] else {
            throw BookAPIError.bookNotFound
        }

        return try parseOpenLibraryBook(bookData, isbn: isbn)
    }

    private func searchOpenLibrary(query: String) async throws -> [BookInfo] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://openlibrary.org/search.json?q=\(encodedQuery)&limit=20"

        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidResponse
        }

        await rateLimiter.waitForToken()
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]] else {
            throw BookAPIError.invalidResponse
        }

        // Parse all results
        let allResults = docs.compactMap { parseOpenLibrarySearchResult($0) }

        return Array(allResults.prefix(20))
    }

    // Parse Volume API response from /api/volumes/brief/
    private func parseVolumeAPIResponse(_ record: [String: Any]) throws -> BookInfo {
        guard let data = record["data"] as? [String: Any],
              let title = data["title"] as? String else {
            throw BookAPIError.invalidResponse
        }

        // Authors
        let authors = (data["authors"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let author = authors.first ?? "Unknown Author"

        // ISBN from identifiers
        var isbn: String?
        if let identifiers = data["identifiers"] as? [String: Any] {
            if let isbn13List = identifiers["isbn_13"] as? [String] {
                isbn = isbn13List.first
            } else if let isbn10List = identifiers["isbn_10"] as? [String] {
                isbn = isbn10List.first
            }
        }

        // Cover from data.cover
        var coverURL: URL?
        if let cover = data["cover"] as? [String: String],
           let large = cover["large"] {
            coverURL = URL(string: large)
        }

        // Pages from data.number_of_pages
        let pages = data["number_of_pages"] as? Int

        // Published date
        let publishedDate = data["publish_date"] as? String

        // Description from details.details.description
        var description: String?
        if let details = record["details"] as? [String: Any],
           let detailsData = details["details"] as? [String: Any] {
            if let desc = detailsData["description"] as? String {
                description = desc
            } else if let descDict = detailsData["description"] as? [String: Any],
                      let value = descDict["value"] as? String {
                description = value
            }
        }

        // Subjects from data.subjects
        let subjects = (data["subjects"] as? [[String: Any]])?.compactMap { $0["name"] as? String }

        // Publisher from data.publishers
        let publishers = (data["publishers"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        let publisher = publishers?.first

        // Language from details.details.languages
        var language: String?
        if let details = record["details"] as? [String: Any],
           let detailsData = details["details"] as? [String: Any],
           let languages = detailsData["languages"] as? [[String: Any]],
           let firstLang = languages.first,
           let key = firstLang["key"] as? String {
            let code = key.replacingOccurrences(of: "/languages/", with: "")
            language = formatLanguageCode(code)
        }

        // OLID from data.identifiers.openlibrary
        var olid: String?
        if let identifiers = data["identifiers"] as? [String: Any],
           let olidList = identifiers["openlibrary"] as? [String] {
            olid = olidList.first
        }

        return BookInfo(
            title: title,
            author: author,
            isbn: isbn,
            coverImageURL: coverURL,
            totalPages: pages,
            publishedDate: publishedDate,
            description: description,
            subjects: subjects,
            publisher: publisher,
            language: language,
            olid: olid,
            workID: nil // Volume API response doesn't include work ID
        )
    }

    private func fetchByOLID(olid: String) async throws -> BookInfo {
        return try await retryPolicy.execute {
            let urlString = "https://openlibrary.org/api/volumes/brief/olid/\(olid).json"

            guard let url = URL(string: urlString) else {
                throw BookAPIError.invalidResponse
            }

            await self.rateLimiter.waitForToken()
            let (data, response) = try await self.urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw BookAPIError.networkError
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let records = json["records"] as? [String: Any],
                  let firstRecord = records.values.first as? [String: Any] else {
                throw BookAPIError.bookNotFound
            }

            return try self.parseVolumeAPIResponse(firstRecord)
        }
    }

    private func parseOpenLibraryBook(_ json: [String: Any], isbn: String) throws -> BookInfo {
        guard let title = json["title"] as? String else {
            throw BookAPIError.invalidResponse
        }

        let authors = (json["authors"] as? [[String: Any]])?.compactMap { $0["name"] as? String } ?? []
        let author = authors.first ?? "Unknown Author"

        let pages = json["number_of_pages"] as? Int

        var coverURL: URL?
        if let cover = json["cover"] as? [String: String],
           let large = cover["large"] {
            coverURL = URL(string: large)
        }

        let publishedDate = json["publish_date"] as? String

        let description: String?
        if let desc = json["description"] as? String {
            description = desc
        } else if let descDict = json["description"] as? [String: Any],
                  let value = descDict["value"] as? String {
            description = value
        } else {
            description = nil
        }

        let subjects = (json["subjects"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        let publishers = (json["publishers"] as? [[String: Any]])?.compactMap { $0["name"] as? String }
        let publisher = publishers?.first

        let language = extractLanguage(from: json)

        return BookInfo(
            title: title,
            author: author,
            isbn: isbn,
            coverImageURL: coverURL,
            totalPages: pages,
            publishedDate: publishedDate,
            description: description,
            subjects: subjects,
            publisher: publisher,
            language: language,
            olid: nil,
            workID: nil
        )
    }

    private func parseOpenLibrarySearchResult(_ json: [String: Any]) -> BookInfo? {
        guard let title = json["title"] as? String else { return nil }

        let authors = (json["author_name"] as? [String]) ?? []
        let author = authors.first ?? "Unknown Author"

        let isbn = (json["isbn"] as? [String])?.first
        let pages = json["number_of_pages_median"] as? Int

        var coverURL: URL?
        if let coverID = json["cover_i"] as? Int {
            coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
        }

        let publishedDate = json["first_publish_year"].flatMap { String(describing: $0) }
        let subjects = (json["subject"] as? [String])?.prefix(8).map { String($0) }
        let publisher = (json["publisher"] as? [String])?.first

        // Extract language from search results
        let languageCodes = json["language"] as? [String]
        let language = languageCodes?.first.map { formatLanguageCode($0) }

        // Get OLID from cover_edition_key
        let olid = json["cover_edition_key"] as? String

        // Get Work ID from key field (e.g., "/works/OL1968368W" -> "OL1968368W")
        var workID: String?
        if let key = json["key"] as? String {
            workID = key.replacingOccurrences(of: "/works/", with: "")
        }

        return BookInfo(
            title: title,
            author: author,
            isbn: isbn,
            coverImageURL: coverURL,
            totalPages: pages,
            publishedDate: publishedDate,
            description: nil, // Will be fetched from Volume API using OLID
            subjects: subjects,
            publisher: publisher,
            language: language,
            olid: olid,
            workID: workID
        )
    }

    // MARK: - Best Edition Selection

    private func fetchBestEditionOLID(workID: String, originalTitle: String) async throws -> String? {
        let urlString = "https://openlibrary.org/works/\(workID)/editions.json?limit=50"

        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidResponse
        }

        await rateLimiter.waitForToken()
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["entries"] as? [[String: Any]] else {
            throw BookAPIError.invalidResponse
        }

        // Find the best edition
        return selectBestEdition(from: entries, matchingTitle: originalTitle)
    }

    private func selectBestEdition(from editions: [[String: Any]], matchingTitle: String) -> String? {
        // Normalize the original title for comparison
        let normalizedOriginalTitle = normalizeTitle(matchingTitle)

        // First, filter editions that match the title exactly or very closely
        let matchingEditions = editions.filter { edition in
            guard let title = edition["title"] as? String else { return false }
            let normalizedEditionTitle = normalizeTitle(title)

            // Only keep editions with exact or near-exact title match
            return normalizedEditionTitle == normalizedOriginalTitle ||
                   levenshteinDistance(normalizedEditionTitle, normalizedOriginalTitle) <= 3
        }

        // If we filtered out everything, fall back to all editions
        let editionsToScore = matchingEditions.isEmpty ? editions : matchingEditions

        // Score each edition
        let scoredEditions = editionsToScore.compactMap { edition -> (olid: String, score: Int)? in
            guard let key = edition["key"] as? String else { return nil }
            let olid = key.replacingOccurrences(of: "/books/", with: "")

            var score = 0

            // +100: Has page count
            if edition["number_of_pages"] != nil {
                score += 100
            }

            // +50: English language
            if let languages = edition["languages"] as? [[String: Any]],
               let firstLang = languages.first,
               let langKey = firstLang["key"] as? String,
               langKey == "/languages/eng" {
                score += 50
            }

            // +30: NOT an ebook/audiobook
            if let physicalFormat = edition["physical_format"] as? String {
                let format = physicalFormat.lowercased()
                if !format.contains("electronic") &&
                   !format.contains("ebook") &&
                   !format.contains("audio") &&
                   !format.contains("mp3") {
                    score += 30
                }
            } else {
                // No physical_format specified = likely physical book
                score += 20
            }

            // +20: Has cover
            if let covers = edition["covers"] as? [Any], !covers.isEmpty {
                score += 20
            }

            // +10: More recent publication (prefer newer editions)
            if let publishDate = edition["publish_date"] as? String,
               let year = extractYear(from: publishDate),
               year >= 2000 {
                score += 10
            }

            return (olid: olid, score: score)
        }

        // Return the highest scored edition
        return scoredEditions.max(by: { $0.score < $1.score })?.olid
    }

    private func normalizeTitle(_ title: String) -> String {
        // Remove common articles, punctuation, and normalize to lowercase
        return title.lowercased()
            .replacingOccurrences(of: "the ", with: "")
            .replacingOccurrences(of: "a ", with: "")
            .replacingOccurrences(of: "an ", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)

        for (i, char1) in s1.enumerated() {
            var cur = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last.last!
    }

    private func extractYear(from dateString: String) -> Int? {
        // Try to extract a 4-digit year from date string
        let pattern = #"(19|20)\d{2}"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)),
           let range = Range(match.range, in: dateString) {
            return Int(dateString[range])
        }
        return nil
    }

    // MARK: - Helper Functions

    private func extractLanguage(from json: [String: Any]) -> String? {
        if let languages = json["languages"] as? [[String: Any]],
           let firstLang = languages.first,
           let key = firstLang["key"] as? String {
            let code = key.replacingOccurrences(of: "/languages/", with: "")
            return formatLanguageCode(code)
        }
        return nil
    }

    private func formatLanguageCode(_ code: String) -> String {
        let languageMap: [String: String] = [
            "eng": "English",
            "ger": "German",
            "spa": "Spanish",
            "fre": "French",
            "ita": "Italian",
            "por": "Portuguese",
            "rus": "Russian",
            "jpn": "Japanese",
            "chi": "Chinese",
            "ara": "Arabic",
            "hin": "Hindi",
            "dut": "Dutch",
            "pol": "Polish",
            "tur": "Turkish",
            "kor": "Korean",
            "ind": "Indonesian"
        ]

        return languageMap[code.lowercased()] ?? code.uppercased()
    }

    private func sanitizeISBN(_ isbn: String) -> String {
        isbn.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private func chooseISBN(_ isbns: [String]) -> String? {
        // Prioritize major English publishers (Penguin, Viking, HarperCollins)
        let preferredEnglishISBNs = [
            "9780140280197", // Penguin - full edition
            "9780670881468", // Viking - original hardcover
            "9780733612275", // HarperCollins Australia
            "9780733614972", // HarperCollins Australia
        ]

        // Check for exact match with known good editions first
        for preferredISBN in preferredEnglishISBNs {
            if isbns.contains(where: { sanitizeISBN($0) == preferredISBN }) {
                return preferredISBN
            }
        }

        // Known English edition ISBN prefixes
        let englishPublisherPrefixes = [
            "978014", // Penguin
            "978067", // Viking/Penguin
            "978073", // HarperCollins Australia
            "978180", // Recent Penguin editions
        ]

        // Try to find ISBN-13 from major English publishers
        for isbn in isbns {
            let clean = sanitizeISBN(isbn)
            if clean.count == 13 {
                for prefix in englishPublisherPrefixes {
                    if clean.hasPrefix(prefix) {
                        return clean
                    }
                }
            }
        }

        // Then prefer any ISBN-13
        for isbn in isbns {
            let clean = sanitizeISBN(isbn)
            if clean.count == 13 {
                return clean
            }
        }

        // Finally, fall back to first ISBN
        return isbns.first.map { sanitizeISBN($0) }
    }

}

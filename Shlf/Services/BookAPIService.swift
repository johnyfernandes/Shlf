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

    var stableID: String {
        if let olid { return "olid:\(olid)" }
        if let workID { return "work:\(workID)" }
        if let isbn { return "isbn:\(isbn)" }
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedAuthor = author.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let year = publishedDate ?? ""
        return "fallback:\(normalizedTitle)|\(normalizedAuthor)|\(year)"
    }
}

struct EditionInfo: Identifiable, Hashable {
    let olid: String
    let title: String
    let publishDate: String?
    let numberOfPages: Int?
    let publishers: [String]?
    let language: String?
    let isbn: String?
    let coverImageURL: URL?

    var id: String { olid }
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
        // iOS 26: Configure URLSession with timeout + aggressive caching
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15  // 15s timeout per request
        config.timeoutIntervalForResource = 30 // 30s total timeout
        config.requestCachePolicy = .returnCacheDataElseLoad

        // Configure URLCache for API response caching
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20MB memory
            diskCapacity: 100 * 1024 * 1024     // 100MB disk
        )

        self.urlSession = URLSession(configuration: config)
        self.rateLimiter = RateLimiter(maxRequestsPerSecond: 10) // Increased from 5 to 10 (still 2x under OpenLibrary limit)
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

    func fetchEditions(workID: String) async throws -> [EditionInfo] {
        try await fetchEditionsOLID(workID: workID)
    }

    func resolveWorkID(isbn: String) async throws -> String? {
        let cleanISBN = sanitizeISBN(isbn)

        guard cleanISBN.count == 10 || cleanISBN.count == 13 else {
            throw BookAPIError.invalidISBN
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        components.path = "/api/books"
        components.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(cleanISBN)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data")
        ]

        guard let url = components.url else {
            throw BookAPIError.invalidResponse
        }

        await rateLimiter.waitForToken()
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bookData = json["ISBN:\(cleanISBN)"] as? [String: Any] else {
            return nil
        }

        return extractWorkID(from: bookData)
    }

    func resolveWorkID(editionID: String) async throws -> String? {
        let trimmedID = editionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedID.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        components.path = "/books/\(trimmedID).json"

        guard let url = components.url else {
            throw BookAPIError.invalidResponse
        }

        await rateLimiter.waitForToken()
        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BookAPIError.invalidResponse
        }

        return extractWorkID(from: json)
    }

    // MARK: - Open Library API

    private func fetchFromOpenLibrary(isbn: String) async throws -> BookInfo {
        let cleanISBN = sanitizeISBN(isbn)

        guard cleanISBN.count == 10 || cleanISBN.count == 13 else {
            throw BookAPIError.invalidISBN
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        components.path = "/api/books"
        components.queryItems = [
            URLQueryItem(name: "bibkeys", value: "ISBN:\(cleanISBN)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "jscmd", value: "data")
        ]

        guard let url = components.url else {
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
        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        components.path = "/search.json"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]

        guard let url = components.url else {
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
        var isbnCandidates: [String] = []
        if let identifiers = data["identifiers"] as? [String: Any] {
            if let isbn13List = identifiers["isbn_13"] as? [String] {
                isbnCandidates.append(contentsOf: isbn13List)
            }
            if let isbn10List = identifiers["isbn_10"] as? [String] {
                isbnCandidates.append(contentsOf: isbn10List)
            }
        }
        let isbn = chooseISBN(isbnCandidates)

        // Cover from data.cover
        var coverURL: URL?
        if let cover = data["cover"] as? [String: String] {
            coverURL = makeCoverURL(from: cover)
        }

        if coverURL == nil,
           let details = record["details"] as? [String: Any],
           let detailsData = details["details"] as? [String: Any],
           let covers = detailsData["covers"] as? [Any] {
            coverURL = makeCoverURL(from: covers)
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

        let workID = extractWorkID(from: data) ?? {
            if let details = record["details"] as? [String: Any],
               let detailsData = details["details"] as? [String: Any] {
                return extractWorkID(from: detailsData)
            }
            return nil
        }()

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
            workID: workID
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
        if let cover = json["cover"] as? [String: String] {
            coverURL = makeCoverURL(from: cover)
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
        let workID = extractWorkID(from: json)

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
            workID: workID
        )
    }

    private func parseOpenLibrarySearchResult(_ json: [String: Any]) -> BookInfo? {
        guard let title = json["title"] as? String else { return nil }

        let authors = (json["author_name"] as? [String]) ?? []
        let author = authors.first ?? "Unknown Author"

        let isbnCandidates = (json["isbn"] as? [String]) ?? []
        let isbn = chooseISBN(isbnCandidates)
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

        // Get OLID from cover_edition_key (or edition_key fallback)
        let coverEditionKey = json["cover_edition_key"] as? String
        let editionKey = (json["edition_key"] as? [String])?.first
        let olid = coverEditionKey ?? editionKey

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
        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        components.path = "/works/\(workID)/editions.json"
        components.queryItems = [
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = components.url else {
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

    private func fetchEditionsOLID(workID: String) async throws -> [EditionInfo] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "openlibrary.org"
        components.path = "/works/\(workID)/editions.json"
        components.queryItems = [
            URLQueryItem(name: "limit", value: "50")
        ]

        guard let url = components.url else {
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

        let editions = entries.compactMap { parseEditionEntry($0) }
        return sortEditions(editions)
    }

    private func parseEditionEntry(_ entry: [String: Any]) -> EditionInfo? {
        guard let key = entry["key"] as? String else { return nil }
        let olid = key.replacingOccurrences(of: "/books/", with: "")
        guard !olid.isEmpty else { return nil }

        let title = entry["title"] as? String ?? "Untitled"
        let publishDate = entry["publish_date"] as? String
        let pages = entry["number_of_pages"] as? Int
        let publishers = entry["publishers"] as? [String]

        let isbn13 = entry["isbn_13"] as? [String] ?? []
        let isbn10 = entry["isbn_10"] as? [String] ?? []
        let isbn = chooseISBN(isbn13 + isbn10)

        var language: String?
        if let languages = entry["languages"] as? [[String: Any]],
           let firstLang = languages.first,
           let key = firstLang["key"] as? String {
            let code = key.replacingOccurrences(of: "/languages/", with: "")
            language = formatLanguageCode(code)
        }

        var coverImageURL: URL?
        if let covers = entry["covers"] as? [Any] {
            coverImageURL = makeCoverURL(from: covers)
        }

        return EditionInfo(
            olid: olid,
            title: title,
            publishDate: publishDate,
            numberOfPages: pages,
            publishers: publishers,
            language: language,
            isbn: isbn,
            coverImageURL: coverImageURL
        )
    }

    private func sortEditions(_ editions: [EditionInfo]) -> [EditionInfo] {
        editions.sorted { first, second in
            let score1 = scoreEdition(first)
            let score2 = scoreEdition(second)
            if score1 != score2 {
                return score1 > score2
            }
            return first.title < second.title
        }
    }

    private func scoreEdition(_ edition: EditionInfo) -> Int {
        var score = 0
        if edition.coverImageURL != nil {
            score += 100
        }
        if edition.numberOfPages != nil {
            score += 50
        }
        if edition.language == "English" {
            score += 20
        }
        if let publishDate = edition.publishDate,
           let year = extractYear(from: publishDate),
           year >= 2000 {
            score += 10
        }
        return score
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

    private func extractWorkID(from json: [String: Any]) -> String? {
        if let works = json["works"] as? [[String: Any]],
           let key = works.first?["key"] as? String {
            return key.replacingOccurrences(of: "/works/", with: "")
        }

        if let key = json["key"] as? String, key.hasPrefix("/works/") {
            return key.replacingOccurrences(of: "/works/", with: "")
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

    private func makeCoverURL(from cover: [String: String]) -> URL? {
        if let large = cover["large"] {
            return URL(string: large)
        }
        if let medium = cover["medium"] {
            return URL(string: medium)
        }
        if let small = cover["small"] {
            return URL(string: small)
        }
        return nil
    }

    private func makeCoverURL(from coverIDs: [Any]) -> URL? {
        guard let first = coverIDs.first else { return nil }
        if let coverID = first as? Int {
            return URL(string: "https://covers.openlibrary.org/b/id/\(coverID)-L.jpg")
        }
        if let coverID = first as? String, let intID = Int(coverID) {
            return URL(string: "https://covers.openlibrary.org/b/id/\(intID)-L.jpg")
        }
        return nil
    }

    private func sanitizeISBN(_ isbn: String) -> String {
        String(isbn.uppercased().filter { $0.isNumber || $0 == "X" })
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

//
//  BookAPIService.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation

struct BookInfo {
    let title: String
    let author: String
    let isbn: String?
    let coverImageURL: URL?
    let totalPages: Int?
    let publishedDate: String?
    let description: String?
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

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Public API

    func fetchBook(isbn: String) async throws -> BookInfo {
        try await fetchFromOpenLibrary(isbn: isbn)
    }

    func searchBooks(query: String) async throws -> [BookInfo] {
        // Use Open Library for search
        try await searchOpenLibrary(query: query)
    }

    // MARK: - Open Library API

    private func fetchFromOpenLibrary(isbn: String) async throws -> BookInfo {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")
        let urlString = "https://openlibrary.org/api/books?bibkeys=ISBN:\(cleanISBN)&format=json&jscmd=data"

        guard let url = URL(string: urlString) else {
            throw BookAPIError.invalidISBN
        }

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

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BookAPIError.networkError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let docs = json["docs"] as? [[String: Any]] else {
            throw BookAPIError.invalidResponse
        }

        return docs.prefix(20).compactMap { parseOpenLibrarySearchResult($0) }
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

        return BookInfo(
            title: title,
            author: author,
            isbn: isbn,
            coverImageURL: coverURL,
            totalPages: pages,
            publishedDate: publishedDate,
            description: nil
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

        return BookInfo(
            title: title,
            author: author,
            isbn: isbn,
            coverImageURL: coverURL,
            totalPages: pages,
            publishedDate: publishedDate,
            description: nil
        )
    }

}

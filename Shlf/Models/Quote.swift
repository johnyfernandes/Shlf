//
//  Quote.swift
//  Shlf
//
//  Created by Claude on 03/12/2025.
//

import Foundation
import SwiftData

@Model
final class Quote {
    var id: UUID = UUID()
    var book: Book?
    var text: String
    var pageNumber: Int?
    var dateAdded: Date = Date()
    var note: String?
    var isFavorite: Bool = false

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        text: String,
        pageNumber: Int? = nil,
        dateAdded: Date = Date(),
        note: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.book = book
        self.text = text
        self.pageNumber = pageNumber
        self.dateAdded = dateAdded
        self.note = note
        self.isFavorite = isFavorite
    }

    // Computed property for list views - return first 100 characters
    var excerpt: String {
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(97)) + "..."
    }

    // Character count for validation
    var characterCount: Int {
        text.count
    }
}

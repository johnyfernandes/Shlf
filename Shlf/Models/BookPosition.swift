//
//  BookPosition.swift
//  Shlf
//
//  Created by Claude on 03/12/2025.
//

import Foundation
import SwiftData

@Model
final class BookPosition {
    var id: UUID = UUID()
    var book: Book?
    var pageNumber: Int
    var lineNumber: Int?
    var timestamp: Date = Date()
    var note: String?

    init(
        id: UUID = UUID(),
        book: Book? = nil,
        pageNumber: Int,
        lineNumber: Int? = nil,
        timestamp: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.book = book
        self.pageNumber = pageNumber
        self.lineNumber = lineNumber
        self.timestamp = timestamp
        self.note = note
    }

    // Computed property for display
    var positionDescription: String {
        var parts = ["Page \(pageNumber)"]
        if let line = lineNumber {
            parts.append("Line \(line)")
        }
        return parts.joined(separator: ", ")
    }
}

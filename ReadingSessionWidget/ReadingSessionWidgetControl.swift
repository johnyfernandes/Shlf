//
//  ReadingSessionWidgetControl.swift
//  ReadingSessionWidget
//
//  Created by Codex on 03/02/2026.
//

import AppIntents
import Foundation
import WidgetKit

struct ReadingWidgetAppEntity: AppEntity, Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let xpToday: Int
    let streak: Int
    // Active session state
    let hasActiveSession: Bool
    let isSessionPaused: Bool
    let sessionStartPage: Int?
    let sessionStartTime: Date?

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"

    static var defaultQuery = ReadingWidgetQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(author)"
        )
    }
}

struct ReadingWidgetQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ReadingWidgetAppEntity] {
        let data = try? ReadingWidgetPersistence.shared.load()
        let books = data?.books ?? []
        if books.isEmpty { return [] }
        return books.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ReadingWidgetAppEntity] {
        let data = try? ReadingWidgetPersistence.shared.load()
        return data?.books ?? []
    }
}

struct ReadingWidgetConfigurationAppIntent: WidgetConfigurationIntent, AppIntent {
    static var title: LocalizedStringResource = "Reading Widget"
    static var description = IntentDescription("Track your reading progress.")

    @Parameter(title: "Book", default: nil)
    var book: ReadingWidgetAppEntity?
}

struct ReadingWidgetPersistenceData: Codable, Sendable {
    let books: [ReadingWidgetAppEntity]
}

class ReadingWidgetPersistence {
    static let shared = ReadingWidgetPersistence()
    private init() {}

    private var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.joaofernandes.Shlf")?.appendingPathComponent("reading_widget.json")
    }

    func save(_ data: ReadingWidgetPersistenceData) throws {
        guard let url else { return }
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(to: url, options: .atomic)
    }

    func load() throws -> ReadingWidgetPersistenceData {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        let raw = try Data(contentsOf: url)
        return try JSONDecoder().decode(ReadingWidgetPersistenceData.self, from: raw)
    }
}

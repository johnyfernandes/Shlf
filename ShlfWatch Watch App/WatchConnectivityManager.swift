//
//  WatchConnectivityManager.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation
import WatchConnectivity
import SwiftData
import OSLog

struct PageDelta: Codable, Sendable {
    let bookUUID: UUID
    let delta: Int
}

struct BookTransfer: Codable, Sendable {
    let id: UUID
    let title: String
    let author: String
    let isbn: String?
    let coverImageURL: String?
    let totalPages: Int?
    let currentPage: Int
    let bookTypeRawValue: String
    let readingStatusRawValue: String
    let dateAdded: Date
    let notes: String
}

class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    nonisolated(unsafe) static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shlf.watch", category: "WatchSync")
    private var modelContext: ModelContext?

    private override init() {
        super.init()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        Self.logger.info("WatchConnectivity activated on Watch")
    }

    func sendPageDelta(_ delta: PageDelta) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        guard WCSession.default.isReachable else {
            Self.logger.warning("iPhone not reachable")
            return
        }

        do {
            let data = try JSONEncoder().encode(delta)
            WCSession.default.sendMessage(
                ["pageDelta": data],
                replyHandler: nil,
                errorHandler: { error in
                    Self.logger.error("Failed to send: \(error)")
                }
            )
            Self.logger.info("Sent page delta: \(delta.delta)")
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    @MainActor
    func syncSessionToPhone(_ session: ReadingSession) async {
        // Session sync will happen automatically via CloudKit
        // This is just a placeholder for future instant sync if needed
        Self.logger.info("Session created, will sync via CloudKit")
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            Self.logger.error("WC activation error: \(error)")
        } else {
            Self.logger.info("WC activated: \(activationState.rawValue)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Self.logger.info("Watch received message")
        // Handle incoming deltas from iPhone if needed
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Self.logger.info("Watch received application context")

        guard let booksData = applicationContext["books"] as? Data else {
            Self.logger.warning("No books data in context")
            return
        }

        Task { @MainActor in
            await self.handleBooksSync(booksData)
        }
    }

    @MainActor
    private func handleBooksSync(_ booksData: Data) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        do {
            let bookTransfers = try JSONDecoder().decode([BookTransfer].self, from: booksData)
            Self.logger.info("Received \(bookTransfers.count) books from iPhone")

            // Fetch existing books
            let descriptor = FetchDescriptor<Book>()
            let existingBooks = try modelContext.fetch(descriptor)

            // Create a map of existing books by UUID for fast lookup
            var existingBooksMap = [UUID: Book]()
            for book in existingBooks {
                existingBooksMap[book.id] = book
            }

            // Track which UUIDs are in the transfer
            var transferredUUIDs = Set<UUID>()

            // Update or insert books
            for transfer in bookTransfers {
                transferredUUIDs.insert(transfer.id)

                if let existingBook = existingBooksMap[transfer.id] {
                    // Update existing book
                    existingBook.title = transfer.title
                    existingBook.author = transfer.author
                    existingBook.isbn = transfer.isbn
                    if let urlString = transfer.coverImageURL {
                        existingBook.coverImageURL = URL(string: urlString)
                    } else {
                        existingBook.coverImageURL = nil
                    }
                    existingBook.totalPages = transfer.totalPages
                    existingBook.currentPage = transfer.currentPage
                    existingBook.bookTypeRawValue = transfer.bookTypeRawValue
                    existingBook.readingStatusRawValue = transfer.readingStatusRawValue
                    existingBook.dateAdded = transfer.dateAdded
                    existingBook.notes = transfer.notes
                } else {
                    // Insert new book
                    let book = Book(
                        id: transfer.id,
                        title: transfer.title,
                        author: transfer.author,
                        isbn: transfer.isbn,
                        coverImageURL: transfer.coverImageURL != nil ? URL(string: transfer.coverImageURL!) : nil,
                        totalPages: transfer.totalPages,
                        currentPage: transfer.currentPage,
                        bookType: BookType(rawValue: transfer.bookTypeRawValue) ?? .physical,
                        readingStatus: ReadingStatus(rawValue: transfer.readingStatusRawValue) ?? .wantToRead,
                        dateAdded: transfer.dateAdded,
                        notes: transfer.notes
                    )
                    modelContext.insert(book)
                }
            }

            // Delete books that are no longer in the iPhone's currently reading list
            for existingBook in existingBooks {
                if !transferredUUIDs.contains(existingBook.id) {
                    modelContext.delete(existingBook)
                }
            }

            try modelContext.save()
            Self.logger.info("Synced \(bookTransfers.count) books to Watch")
        } catch {
            Self.logger.error("Failed to handle books sync: \(error)")
        }
    }
}

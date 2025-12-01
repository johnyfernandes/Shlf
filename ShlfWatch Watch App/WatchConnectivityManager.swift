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

extension Logger {
    nonisolated(unsafe) static let watchSync = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shlf.watch", category: "WatchSync")
}

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
        Logger.watchSync.info("WatchConnectivity activated on Watch")
    }

    func sendPageDelta(_ delta: PageDelta) {
        guard WCSession.default.activationState == .activated else {
            Logger.watchSync.warning("WC not activated")
            return
        }

        guard WCSession.default.isReachable else {
            Logger.watchSync.warning("iPhone not reachable")
            return
        }

        do {
            let data = try JSONEncoder().encode(delta)
            WCSession.default.sendMessage(
                ["pageDelta": data],
                replyHandler: nil,
                errorHandler: { error in
                    Logger.watchSync.error("Failed to send: \(error)")
                }
            )
            Logger.watchSync.info("Sent page delta: \(delta.delta)")
        } catch {
            Logger.watchSync.error("Encoding error: \(error)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            Logger.watchSync.error("WC activation error: \(error)")
        } else {
            Logger.watchSync.info("WC activated: \(activationState.rawValue)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Logger.watchSync.info("Watch received message")
        // Handle incoming deltas from iPhone if needed
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Logger.watchSync.info("Watch received application context")

        guard let booksData = applicationContext["books"] as? Data else {
            Logger.watchSync.warning("No books data in context")
            return
        }

        Task { @MainActor in
            await self.handleBooksSync(booksData)
        }
    }

    @MainActor
    private func handleBooksSync(_ booksData: Data) async {
        guard let modelContext = modelContext else {
            Logger.watchSync.warning("ModelContext not configured")
            return
        }

        do {
            let bookTransfers = try JSONDecoder().decode([BookTransfer].self, from: booksData)
            Logger.watchSync.info("Received \(bookTransfers.count) books from iPhone")

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
            Logger.watchSync.info("Synced \(bookTransfers.count) books to Watch")
        } catch {
            Logger.watchSync.error("Failed to handle books sync: \(error)")
        }
    }
}

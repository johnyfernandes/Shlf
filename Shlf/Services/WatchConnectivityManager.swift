//
//  WatchConnectivityManager.swift
//  Shlf
//
//  Created by João Fernandes on 28/11/2025.
//

import Foundation
import WatchConnectivity
import SwiftData
import OSLog

extension Notification.Name {
    nonisolated(unsafe) static let watchReachabilityDidChange = Notification.Name("watchReachabilityDidChange")
}

private enum ReadingConstants {
    static let defaultMaxPages = 1000
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
    nonisolated(unsafe) static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shlf.app", category: "WatchSync")

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
        Self.logger.info("WatchConnectivity activated on iPhone")
    }

    @MainActor
    func syncBooksToWatch() async {
        guard WCSession.default.activationState == .activated,
              let modelContext = modelContext else {
            Self.logger.warning("Cannot sync - WC not activated or context not configured")
            return
        }

        do {
            // Fetch all currently reading books
            let descriptor = FetchDescriptor<Book>(
                sortBy: [SortDescriptor(\.title)]
            )
            let allBooks = try modelContext.fetch(descriptor)
            let currentlyReading = allBooks.filter { $0.readingStatus == .currentlyReading }

            Self.logger.info("Syncing \(currentlyReading.count) books to Watch...")

            // Convert books to transferable format
            let bookTransfers = currentlyReading.map { book in
                BookTransfer(
                    id: book.id,
                    title: book.title,
                    author: book.author,
                    isbn: book.isbn,
                    coverImageURL: book.coverImageURL?.absoluteString,
                    totalPages: book.totalPages,
                    currentPage: book.currentPage,
                    bookTypeRawValue: book.bookTypeRawValue,
                    readingStatusRawValue: book.readingStatusRawValue,
                    dateAdded: book.dateAdded,
                    notes: book.notes
                )
            }

            let data = try JSONEncoder().encode(bookTransfers)

            // Use updateApplicationContext for guaranteed delivery
            try WCSession.default.updateApplicationContext(["books": data])
            Self.logger.info("Sent \(bookTransfers.count) books to Watch")
        } catch {
            Self.logger.error("Failed to sync books: \(error)")
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
            Self.logger.error("WC activation error: \(error)")
        } else {
            Self.logger.info("WC activated: \(activationState.rawValue)")
            // Sync books to watch when activated
            Task { @MainActor in
                await WatchConnectivityManager.shared.syncBooksToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        Self.logger.warning("WC session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Self.logger.warning("WC session deactivated")
        // Reactivate session for new watch
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        NotificationCenter.default.post(name: .watchReachabilityDidChange, object: nil)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Self.logger.info("iPhone received message")

        guard let pageDeltaData = message["pageDelta"] as? Data else {
            Self.logger.warning("Invalid message format")
            return
        }

        Task { @MainActor in
            do {
                let delta = try JSONDecoder().decode(PageDelta.self, from: pageDeltaData)
                Self.logger.info("Received page delta: \(delta.delta) for book")
                await self.handlePageDelta(delta)
            } catch {
                Self.logger.error("Decoding error: \(error)")
            }
        }
    }

    @MainActor
    private func handlePageDelta(_ delta: PageDelta) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        do {
            // Fetch the book by UUID
            let descriptor = FetchDescriptor<Book>(
                predicate: #Predicate<Book> { book in
                    book.id == delta.bookUUID
                }
            )
            let books = try modelContext.fetch(descriptor)

            guard let book = books.first else {
                Self.logger.warning("Book not found with UUID: \(delta.bookUUID)")
                return
            }

            // Update current page
            book.currentPage = min((book.totalPages ?? ReadingConstants.defaultMaxPages), book.currentPage + delta.delta)

            // Save context
            try modelContext.save()

            Self.logger.info("Updated book: \(book.title) to page \(book.currentPage)")

            // Update Live Activity if running
            await ReadingSessionActivityManager.shared.updateCurrentPage(book.currentPage)
        } catch {
            Self.logger.error("Failed to update book: \(error)")
        }
    }
}

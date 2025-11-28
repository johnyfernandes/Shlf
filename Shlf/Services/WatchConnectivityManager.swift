//
//  WatchConnectivityManager.swift
//  Shlf
//
//  Created by João Fernandes on 28/11/2025.
//

import Foundation
import WatchConnectivity
import SwiftData

struct PageDelta: Codable {
    let bookID: PersistentIdentifier
    let delta: Int
}

struct BookTransfer: Codable {
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
        print("📱 WatchConnectivity activated on iPhone")
    }

    @MainActor
    func syncBooksToWatch() async {
        guard WCSession.default.activationState == .activated,
              let modelContext = modelContext else {
            print("⚠️ Cannot sync - WC not activated or context not configured")
            return
        }

        do {
            // Fetch all currently reading books
            let descriptor = FetchDescriptor<Book>(
                sortBy: [SortDescriptor(\.title)]
            )
            let allBooks = try modelContext.fetch(descriptor)
            let currentlyReading = allBooks.filter { $0.readingStatus == .currentlyReading }

            print("📤 Syncing \(currentlyReading.count) books to Watch...")

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
            print("✅ Sent \(bookTransfers.count) books to Watch")
        } catch {
            print("❌ Failed to sync books: \(error)")
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
            print("❌ WC activation error: \(error)")
        } else {
            print("✅ WC activated: \(activationState.rawValue)")
            // Sync books to watch when activated
            Task { @MainActor in
                await WatchConnectivityManager.shared.syncBooksToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("⚠️ WC session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("⚠️ WC session deactivated")
        // Reactivate session for new watch
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        print("📥 iPhone received message")

        guard let pageDeltaData = message["pageDelta"] as? Data else {
            print("⚠️ Invalid message format")
            return
        }

        do {
            let delta = try JSONDecoder().decode(PageDelta.self, from: pageDeltaData)
            print("📥 Received page delta: \(delta.delta) for book")

            // Update book on main actor
            Task { @MainActor in
                await self.handlePageDelta(delta)
            }
        } catch {
            print("❌ Decoding error: \(error)")
        }
    }

    @MainActor
    private func handlePageDelta(_ delta: PageDelta) async {
        guard let modelContext = modelContext else {
            print("⚠️ ModelContext not configured")
            return
        }

        do {
            // Fetch the book by persistent identifier
            let book = modelContext.model(for: delta.bookID) as? Book

            guard let book = book else {
                print("⚠️ Book not found")
                return
            }

            // Update current page
            book.currentPage = min((book.totalPages ?? 1000), book.currentPage + delta.delta)

            // Save context
            try modelContext.save()

            print("✅ Updated book: \(book.title) to page \(book.currentPage)")

            // Update Live Activity if running
            await ReadingSessionActivityManager.shared.updateCurrentPage(book.currentPage)
        } catch {
            print("❌ Failed to update book: \(error)")
        }
    }
}

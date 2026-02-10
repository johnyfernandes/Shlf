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

private enum ReadingConstants {
    static let defaultMaxPages = 1000
}

private let watchLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shlf.app", category: "WatchSync")

class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    static let languageOverrideKey = "languageOverride"

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    private var lastActiveSessionEndDate: Date?
    private var endedActiveSessionIDs: [UUID: Date] = [:] // Track UUID -> timestamp when ended
    private var lastLiveActivityStateTimestamp: Date?
    private var lastPageUpdateTimestamps: [UUID: Date] = [:]
    private var syncInProgress = false
    private var syncPending = false

    private override init() {
        super.init()

        // Schedule periodic cleanup of old endedActiveSessionIDs (every hour)
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupOldEndedSessionIDs()
        }
    }

    func configure(modelContext: ModelContext, container: ModelContainer? = nil) {
        self.modelContext = modelContext
        self.modelContainer = container
    }

    /// Cleanup old ended session IDs (older than 24 hours) to prevent unbounded memory growth
    private func cleanupOldEndedSessionIDs() {
        let threshold = Date().addingTimeInterval(-24 * 3600) // 24 hours ago
        let oldCount = endedActiveSessionIDs.count

        endedActiveSessionIDs = endedActiveSessionIDs.filter { _, timestamp in
            timestamp > threshold
        }

        let removedCount = oldCount - endedActiveSessionIDs.count
        if removedCount > 0 {
            watchLogger.info("🧹 Cleaned up \(removedCount) old ended session IDs (kept \(self.endedActiveSessionIDs.count))")
        }
    }

    // Fallback for background WC events when the app hasn't configured the context yet
    @MainActor
    private func resolvedModelContext() -> ModelContext? {
        if let modelContext {
            return modelContext
        }
        if let container = try? SwiftDataConfig.createModelContainer() {
            let ctx = container.mainContext
            self.modelContext = ctx
            return ctx
        }
        return nil
    }

    @MainActor
    private func makeSyncContext() -> ModelContext? {
        if let modelContainer {
            return ModelContext(modelContainer)
        }
        if let container = try? SwiftDataConfig.createModelContainer() {
            self.modelContainer = container
            return ModelContext(container)
        }
        return modelContext
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        watchLogger.info("WatchConnectivity activated on iPhone")
    }

    func sendLanguageOverrideToWatch(_ rawValue: String) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        var context = WCSession.default.applicationContext
        context[Self.languageOverrideKey] = rawValue

        do {
            try WCSession.default.updateApplicationContext(context)
            watchLogger.info("📤 Sent language override to Watch: \(rawValue)")
        } catch {
            watchLogger.error("Failed to update language override context: \(error)")
        }
    }

    func sendPageDeltaToWatch(bookUUID: UUID, delta: Int, newPage: Int? = nil) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        do {
            let pageDelta = PageDelta(bookUUID: bookUUID, delta: delta, newPage: newPage)
            let data = try JSONEncoder().encode(pageDelta)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["pageDelta": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("❌ sendMessage failed: \(error.localizedDescription)")
                        // Automatic fallback to guaranteed delivery
                        WCSession.default.transferUserInfo(["pageDelta": data])
                        watchLogger.info("↩️ Auto-fallback: Queued page delta for guaranteed delivery")
                    }
                )
                watchLogger.info("📤 Sent page delta (instant): \(delta)")
            } else {
                WCSession.default.transferUserInfo(["pageDelta": data])
                watchLogger.info("📦 Queued page delta (guaranteed): \(delta)")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendSessionDeletionToWatch(sessionIds: [UUID]) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        guard !sessionIds.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(sessionIds)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["sessionDeletion": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("Failed to send session deletion to Watch: \(error)")
                    }
                )
                watchLogger.info("📤 Sent session deletion to Watch: \(sessionIds.count) session(s)")
            } else {
                WCSession.default.transferUserInfo(["sessionDeletion": data])
                watchLogger.info("📦 Queued session deletion to Watch: \(sessionIds.count) session(s)")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendSessionToWatch(_ session: ReadingSession) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        guard let bookId = session.book?.id else {
            watchLogger.warning("Cannot send session without book")
            return
        }

        do {
            let transfer = SessionTransfer(
                id: session.id,
                bookId: bookId,
                startDate: session.startDate,
                endDate: session.endDate,
                startPage: session.startPage,
                endPage: session.endPage,
                durationMinutes: session.durationMinutes,
                xpEarned: session.xpEarned,
                isAutoGenerated: session.isAutoGenerated,
                countsTowardStats: session.countsTowardStats,
                isImported: session.isImported
            )

            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["session": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("Failed to send session to Watch: \(error)")
                    }
                )
                watchLogger.info("Sent session to Watch: \(session.pagesRead) pages")
            } else {
                WCSession.default.transferUserInfo(["session": data])
                watchLogger.info("Queued session to Watch: \(session.pagesRead) pages")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendActiveSessionUpdateToWatch(_ activeSession: ActiveReadingSession) {
        sendActiveSessionToWatch(activeSession)
    }

    func sendProfileSettingsToWatch(_ profile: UserProfile) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let transfer = ProfileSettingsTransfer(
                hideAutoSessionsIPhone: profile.hideAutoSessionsIPhone,
                hideAutoSessionsWatch: profile.hideAutoSessionsWatch,
                showSettingsOnWatch: profile.showSettingsOnWatch,
                useCircularProgressWatch: profile.useCircularProgressWatch,
                enableWatchPositionMarking: profile.enableWatchPositionMarking,
                themeColorRawValue: profile.themeColorRawValue,
                streaksPaused: profile.streaksPaused
            )
            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["profileSettings": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("Failed to send profile settings: \(error)")
                    }
                )
                watchLogger.info("Sent profile settings to Watch")
            } else {
                WCSession.default.transferUserInfo(["profileSettings": data])
                watchLogger.info("Queued profile settings to Watch")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendProfileStatsToWatch(_ profile: UserProfile) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let transfer = ProfileStatsTransfer(
                totalXP: profile.totalXP,
                currentStreak: profile.currentStreak,
                longestStreak: profile.longestStreak,
                lastReadingDate: profile.lastReadingDate,
                syncTimestamp: Date()
            )
            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["profileStats": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("❌ sendMessage failed: \(error.localizedDescription)")
                        // Automatic fallback to guaranteed delivery
                        WCSession.default.transferUserInfo(["profileStats": data])
                        watchLogger.info("↩️ Auto-fallback: Queued profile stats")
                    }
                )
                watchLogger.info("📤 Sent profile stats (instant): XP=\(profile.totalXP)")
            } else {
                WCSession.default.transferUserInfo(["profileStats": data])
                watchLogger.info("📦 Queued profile stats (guaranteed): XP=\(profile.totalXP)")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendActiveSessionToWatch(_ activeSession: ActiveReadingSession) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        guard let bookId = activeSession.book?.id else {
            watchLogger.warning("Cannot send active session without book")
            return
        }

        do {
            let transfer = ActiveSessionTransfer(
                id: activeSession.id,
                bookId: bookId,
                startDate: activeSession.startDate,
                currentPage: activeSession.currentPage,
                startPage: activeSession.startPage,
                isPaused: activeSession.isPaused,
                pausedAt: activeSession.pausedAt,
                totalPausedDuration: activeSession.totalPausedDuration,
                lastUpdated: activeSession.lastUpdated,
                sourceDevice: activeSession.sourceDevice,
                sentAt: Date()
            )

            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["activeSession": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("❌ sendMessage failed: \(error.localizedDescription)")
                        WCSession.default.transferUserInfo(["activeSession": data])
                        watchLogger.info("↩️ Auto-fallback: Queued active session")
                    }
                )
                watchLogger.info("📤 Sent active session (instant): \(activeSession.pagesRead) pages")
            } else {
                WCSession.default.transferUserInfo(["activeSession": data])
                watchLogger.info("📦 Queued active session (guaranteed): \(activeSession.pagesRead) pages")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendActiveSessionEndToWatch(activeSessionId: UUID? = nil) {
        guard WCSession.default.activationState == .activated else { return }

        var payload: [String: Any] = ["activeSessionEnd": true]
        if let id = activeSessionId {
            payload["activeSessionEndId"] = id.uuidString
            endedActiveSessionIDs[id] = Date()
        }

        // Use transferUserInfo so the end signal always lands and doesn't block UI
        WCSession.default.transferUserInfo(payload)
        watchLogger.info("📦 Queued active session end (guaranteed)")
    }

    /// Sends a consolidated session completion message to Watch (ATOMIC - replaces separate messages)
    /// Combines activeSessionEnd, completedSession, and liveActivityEnd into a single atomic transfer
    func sendSessionCompletionToWatch(activeSessionId: UUID, completedSession: ReadingSession) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        guard let bookId = completedSession.book?.id else {
            watchLogger.warning("Session has no book")
            return
        }

        do {
            let sessionTransfer = SessionTransfer(
                id: completedSession.id,
                bookId: bookId,
                startDate: completedSession.startDate,
                endDate: completedSession.endDate,
                startPage: completedSession.startPage,
                endPage: completedSession.endPage,
                durationMinutes: completedSession.durationMinutes,
                xpEarned: completedSession.xpEarned,
                isAutoGenerated: completedSession.isAutoGenerated,
                countsTowardStats: completedSession.countsTowardStats,
                isImported: completedSession.isImported
            )

            let completion = SessionCompletionTransfer(
                activeSessionId: activeSessionId,
                completedSession: sessionTransfer,
                endLiveActivity: true
            )

            let data = try JSONEncoder().encode(completion)

            // ALWAYS use transferUserInfo for session completion to guarantee atomic delivery
            WCSession.default.transferUserInfo(["sessionCompletion": data])
            endedActiveSessionIDs[activeSessionId] = Date()

            watchLogger.info("📦 Queued session completion to Watch (atomic): \(completedSession.endPage - completedSession.startPage) pages, \(completedSession.xpEarned) XP")
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendBookPositionToWatch(_ position: BookPosition) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        guard let bookId = position.book?.id else {
            watchLogger.warning("Cannot send position without book")
            return
        }

        do {
            let transfer = BookPositionTransfer(
                id: position.id,
                bookId: bookId,
                pageNumber: position.pageNumber,
                lineNumber: position.lineNumber,
                timestamp: position.timestamp,
                note: position.note
            )

            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["bookPosition": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("Failed to send position to Watch: \(error)")
                    }
                )
                watchLogger.info("Sent position to Watch: Page \(position.pageNumber)")
            } else {
                WCSession.default.transferUserInfo(["bookPosition": data])
                watchLogger.info("Queued position to Watch: Page \(position.pageNumber)")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    func sendQuotesToWatch(for book: Book) {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("WC not activated")
            return
        }

        guard let quotes = book.quotes, !quotes.isEmpty else {
            watchLogger.info("No quotes to send for book")
            return
        }

        do {
            let transfers = quotes.map { quote in
                QuoteTransfer(
                    id: quote.id,
                    bookId: book.id,
                    text: quote.text,
                    pageNumber: quote.pageNumber,
                    dateAdded: quote.dateAdded,
                    note: quote.note,
                    isFavorite: quote.isFavorite
                )
            }

            let data = try JSONEncoder().encode(transfers)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["quotes": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        watchLogger.error("Failed to send quotes to Watch: \(error)")
                    }
                )
                watchLogger.info("Sent \(quotes.count) quotes to Watch")
            } else {
                WCSession.default.transferUserInfo(["quotes": data])
                watchLogger.info("Queued \(quotes.count) quotes to Watch")
            }
        } catch {
            watchLogger.error("Encoding error: \(error)")
        }
    }

    @MainActor
    func syncBooksToWatch() async {
        syncPending = true
        guard !syncInProgress else { return }
        syncInProgress = true

        defer {
            syncInProgress = false
        }

        while syncPending {
            syncPending = false
            await Task.yield()
            try? await Task.sleep(nanoseconds: 120_000_000)
            await performSyncBooksToWatch()
        }
    }

    @MainActor
    private func performSyncBooksToWatch() async {
        guard WCSession.default.activationState == .activated else {
            watchLogger.warning("Cannot sync - WC not activated")
            return
        }

        if let modelContext {
            do {
                try modelContext.save()
            } catch {
                watchLogger.error("Pre-sync save failed: \(error)")
            }
        }

        guard let syncContext = makeSyncContext() else {
            watchLogger.warning("Cannot sync - context not configured")
            return
        }

        do {
            // Fetch all currently reading books
            let booksDescriptor = FetchDescriptor<Book>(
                sortBy: [SortDescriptor(\.title)]
            )
            let allBooks = try syncContext.fetch(booksDescriptor)
            let currentlyReading = allBooks.filter { $0.readingStatus == .currentlyReading }

            watchLogger.info("Syncing \(currentlyReading.count) books to Watch...")

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

            // Fetch sessions for currently reading books
            let bookIds = currentlyReading.map { $0.id }
            let sessionsDescriptor = FetchDescriptor<ReadingSession>(
                sortBy: [SortDescriptor(\.startDate, order: .reverse)]
            )
            let allSessions = try syncContext.fetch(sessionsDescriptor)
            let relevantSessions = allSessions.filter { session in
                guard let book = session.book else { return false }
                return bookIds.contains(book.id)
            }

            watchLogger.info("Syncing \(relevantSessions.count) sessions to Watch...")

            // Convert sessions to transferable format
            let sessionTransfers = relevantSessions.compactMap { session -> SessionTransfer? in
                guard let bookId = session.book?.id else { return nil }
                return SessionTransfer(
                    id: session.id,
                    bookId: bookId,
                    startDate: session.startDate,
                    endDate: session.endDate,
                    startPage: session.startPage,
                    endPage: session.endPage,
                    durationMinutes: session.durationMinutes,
                    xpEarned: session.xpEarned,
                    isAutoGenerated: session.isAutoGenerated,
                    countsTowardStats: session.countsTowardStats,
                    isImported: session.isImported
                )
            }

            let booksData = try JSONEncoder().encode(bookTransfers)
            let sessionsData = try JSONEncoder().encode(sessionTransfers)

            var context: [String: Any] = [
                "books": booksData,
                "sessions": sessionsData
            ]
            if let languageOverride = UserDefaults.standard.string(forKey: "developerLanguageOverride") {
                context[Self.languageOverrideKey] = languageOverride
            }

            // Use updateApplicationContext for guaranteed delivery
            try WCSession.default.updateApplicationContext(context)
            watchLogger.info("Sent \(bookTransfers.count) books and \(sessionTransfers.count) sessions to Watch")
        } catch {
            watchLogger.error("Failed to sync to Watch: \(error)")
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
            watchLogger.error("WC activation error: \(error)")
        } else {
            watchLogger.info("WC activated: \(activationState.rawValue)")
            // Sync books to watch when activated
            Task { @MainActor in
                await WatchConnectivityManager.shared.syncBooksToWatch()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        watchLogger.warning("WC session became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        watchLogger.warning("WC session deactivated")
        // Reactivate session for new watch
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        NotificationCenter.default.post(name: Notification.Name("watchReachabilityDidChange"), object: nil)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        watchLogger.info("iPhone received message")

        // Handle page delta
        if let pageDeltaData = message["pageDelta"] as? Data {
            Task { @MainActor in
                do {
                    let delta = try JSONDecoder().decode(PageDelta.self, from: pageDeltaData)
                    watchLogger.info("Received page delta: \(delta.delta) for book")
                    await self.handlePageDelta(delta)
                } catch {
                    watchLogger.error("Page delta decoding error: \(error)")
                }
            }
        }

        // Handle session from Watch
        if let sessionData = message["session"] as? Data {
            Task { @MainActor in
                do {
                    let sessionTransfer = try JSONDecoder().decode(SessionTransfer.self, from: sessionData)
                    watchLogger.info("Received session from Watch: \(sessionTransfer.endPage - sessionTransfer.startPage) pages")
                    await self.handleWatchSession(sessionTransfer)
                } catch {
                    watchLogger.error("Session decoding error: \(error)")
                }
            }
        }

        // Handle profile settings from Watch
        if let profileData = message["profileSettings"] as? Data {
            Task { @MainActor in
                do {
                    let settings = try JSONDecoder().decode(ProfileSettingsTransfer.self, from: profileData)
                    watchLogger.info("Received profile settings from Watch")
                    await self.handleProfileSettings(settings)
                } catch {
                    watchLogger.error("Profile settings decoding error: \(error)")
                }
            }
        }

        // Handle profile stats from Watch
        if let statsData = message["profileStats"] as? Data {
            Task { @MainActor in
                do {
                    let stats = try JSONDecoder().decode(ProfileStatsTransfer.self, from: statsData)
                    watchLogger.info("Received profile stats from Watch: XP=\(stats.totalXP), Streak=\(stats.currentStreak)")
                    await self.handleProfileStats(stats)
                } catch {
                    watchLogger.error("Profile stats decoding error: \(error)")
                }
            }
        }

        // Handle Live Activity start from Watch
        if let liveActivityData = message["liveActivityStart"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityStartTransfer.self, from: liveActivityData)
                    watchLogger.info("Received Live Activity start from Watch: \(transfer.bookTitle)")
                    await self.handleLiveActivityStart(transfer)
                } catch {
                    watchLogger.error("Live Activity start decoding error: \(error)")
                }
            }
        }

        // Handle Live Activity update from Watch
        if let liveActivityData = message["liveActivityUpdate"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityUpdateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityUpdate(transfer)
                } catch {
                    watchLogger.error("Live Activity update decoding error: \(error)")
                }
            }
        }

        // Handle Live Activity state change from Watch
        if let liveActivityData = message["liveActivityState"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityStateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityState(transfer)
                } catch {
                    watchLogger.error("Live Activity state decoding error: \(error)")
                }
            }
        }

        // Handle Live Activity end from Watch
        if message["liveActivityEnd"] != nil {
            Task { @MainActor in
                await self.handleLiveActivityEnd()
            }
        }

        // Handle active session from Watch
        if let activeSessionData = message["activeSession"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(ActiveSessionTransfer.self, from: activeSessionData)
                    watchLogger.info("Received active session from Watch: \(transfer.pagesRead) pages")
                    await self.handleActiveSession(transfer)
                } catch {
                    watchLogger.error("Active session decoding error: \(error)")
                }
            }
        }

        // Handle active session end from Watch
        if message["activeSessionEnd"] != nil {
            Task { @MainActor in
                let idString = message["activeSessionEndId"] as? String
                await self.handleActiveSessionEnd(endedId: idString.flatMap(UUID.init))
            }
        }

        // ✅ Handle consolidated session completion from Watch (PREFERRED)
        if let completionData = message["sessionCompletion"] as? Data {
            Task { @MainActor in
                do {
                    let completion = try JSONDecoder().decode(SessionCompletionTransfer.self, from: completionData)
                    watchLogger.info("✅ Received atomic session completion from Watch: \(completion.completedSession.endPage - completion.completedSession.startPage) pages")
                    await self.handleSessionCompletion(completion)
                } catch {
                    watchLogger.error("Session completion decoding error: \(error)")
                }
            }
        }

        // Handle book position from Watch
        if let positionData = message["bookPosition"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(BookPositionTransfer.self, from: positionData)
                    watchLogger.info("Received book position from Watch: Page \(transfer.pageNumber)")
                    await self.handleBookPosition(transfer)
                } catch {
                    watchLogger.error("Book position decoding error: \(error)")
                }
            }
        }

        // Handle quotes from Watch
        if let quotesData = message["quotes"] as? Data {
            Task { @MainActor in
                do {
                    let transfers = try JSONDecoder().decode([QuoteTransfer].self, from: quotesData)
                    watchLogger.info("Received \(transfers.count) quotes from Watch")
                    await self.handleQuotes(transfers)
                } catch {
                    watchLogger.error("Quotes decoding error: \(error)")
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        watchLogger.info("iPhone received userInfo payload")

        if let pageDeltaData = userInfo["pageDelta"] as? Data {
            Task { @MainActor in
                do {
                    let delta = try JSONDecoder().decode(PageDelta.self, from: pageDeltaData)
                    watchLogger.info("Received queued page delta: \(delta.delta)")
                    await self.handlePageDelta(delta)
                } catch {
                    watchLogger.error("Page delta userInfo decoding error: \(error)")
                }
            }
        }

        if let sessionData = userInfo["session"] as? Data {
            Task { @MainActor in
                do {
                    let sessionTransfer = try JSONDecoder().decode(SessionTransfer.self, from: sessionData)
                    watchLogger.info("Received queued session from Watch: \(sessionTransfer.endPage - sessionTransfer.startPage) pages")
                    await self.handleWatchSession(sessionTransfer)
                } catch {
                    watchLogger.error("Session userInfo decoding error: \(error)")
                }
            }
        }

        if let profileData = userInfo["profileSettings"] as? Data {
            Task { @MainActor in
                do {
                    let settings = try JSONDecoder().decode(ProfileSettingsTransfer.self, from: profileData)
                    watchLogger.info("Received queued profile settings from Watch")
                    await self.handleProfileSettings(settings)
                } catch {
                    watchLogger.error("Profile settings userInfo decoding error: \(error)")
                }
            }
        }

        if let statsData = userInfo["profileStats"] as? Data {
            Task { @MainActor in
                do {
                    let stats = try JSONDecoder().decode(ProfileStatsTransfer.self, from: statsData)
                    watchLogger.info("Received queued profile stats from Watch: XP=\(stats.totalXP), Streak=\(stats.currentStreak)")
                    await self.handleProfileStats(stats)
                } catch {
                    watchLogger.error("Profile stats userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity start from Watch
        if let liveActivityData = userInfo["liveActivityStart"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityStartTransfer.self, from: liveActivityData)
                    watchLogger.info("📦 Received queued Live Activity start from Watch: \(transfer.bookTitle)")
                    await self.handleLiveActivityStart(transfer)
                } catch {
                    watchLogger.error("Live Activity start userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity update from Watch
        if let liveActivityData = userInfo["liveActivityUpdate"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityUpdateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityUpdate(transfer)
                } catch {
                    watchLogger.error("Live Activity update userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity state change from Watch
        if let liveActivityData = userInfo["liveActivityState"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityStateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityState(transfer)
                } catch {
                    watchLogger.error("Live Activity state userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity end from Watch
        if userInfo["liveActivityEnd"] != nil {
            Task { @MainActor in
                await self.handleLiveActivityEnd()
            }
        }

        // Handle queued active session from Watch
        if let activeSessionData = userInfo["activeSession"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(ActiveSessionTransfer.self, from: activeSessionData)
                    watchLogger.info("📦 Received queued active session from Watch: \(transfer.pagesRead) pages")
                    await self.handleActiveSession(transfer)
                } catch {
                    watchLogger.error("Active session userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued active session end from Watch
        if userInfo["activeSessionEnd"] != nil {
            Task { @MainActor in
                let idString = userInfo["activeSessionEndId"] as? String
                await self.handleActiveSessionEnd(endedId: idString.flatMap(UUID.init))
            }
        }

        // ✅ Handle queued consolidated session completion from Watch (PREFERRED)
        if let completionData = userInfo["sessionCompletion"] as? Data {
            Task { @MainActor in
                do {
                    let completion = try JSONDecoder().decode(SessionCompletionTransfer.self, from: completionData)
                    watchLogger.info("✅📦 Received queued atomic session completion from Watch: \(completion.completedSession.endPage - completion.completedSession.startPage) pages")
                    await self.handleSessionCompletion(completion)
                } catch {
                    watchLogger.error("Session completion userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued book position from Watch
        if let positionData = userInfo["bookPosition"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(BookPositionTransfer.self, from: positionData)
                    watchLogger.info("📦 Received queued book position from Watch: Page \(transfer.pageNumber)")
                    await self.handleBookPosition(transfer)
                } catch {
                    watchLogger.error("Book position userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued quotes from Watch
        if let quotesData = userInfo["quotes"] as? Data {
            Task { @MainActor in
                do {
                    let transfers = try JSONDecoder().decode([QuoteTransfer].self, from: quotesData)
                    watchLogger.info("📦 Received queued \(transfers.count) quotes from Watch")
                    await self.handleQuotes(transfers)
                } catch {
                    watchLogger.error("Quotes userInfo decoding error: \(error)")
                }
            }
        }
    }

    @MainActor
    private func handlePageDelta(_ delta: PageDelta) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
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
                watchLogger.warning("Book not found with UUID: \(delta.bookUUID)")
                return
            }

            if let lastTimestamp = lastPageUpdateTimestamps[delta.bookUUID],
               delta.timestamp <= lastTimestamp {
                watchLogger.info("Ignoring stale page update for book \(delta.bookUUID)")
                return
            }
            lastPageUpdateTimestamps[delta.bookUUID] = delta.timestamp

            // Update current page
            let maxPages = book.totalPages ?? ReadingConstants.defaultMaxPages
            let targetPage = delta.newPage ?? (book.currentPage + delta.delta)
            book.currentPage = min(maxPages, max(0, targetPage))

            // Save context
            try modelContext.save()

            watchLogger.info("Updated book: \(book.title) to page \(book.currentPage)")

            // Update Live Activity if running
            await ReadingSessionActivityManager.shared.updateCurrentPage(book.currentPage)

            // Refresh widget with updated progress
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        } catch {
            watchLogger.error("Failed to update book: \(error)")
        }
    }

    /// Check for duplicate sessions (same book, overlapping time range)
    @MainActor
    private func findDuplicateSession(for transfer: SessionTransfer, in modelContext: ModelContext) -> ReadingSession? {
        // Fetch all sessions for this book
        let bookId = transfer.bookId
        let descriptor = FetchDescriptor<ReadingSession>()
        guard let allSessions = try? modelContext.fetch(descriptor) else { return nil }

        let bookSessions = allSessions.filter { $0.book?.id == bookId && $0.id != transfer.id }

        // Check for overlapping time ranges (within 5 minutes tolerance)
        let tolerance: TimeInterval = 300 // 5 minutes
        for session in bookSessions {
            let sessionStart = session.startDate
            let sessionEnd = session.endDate ?? Date()
            let transferStart = transfer.startDate
            let transferEnd = transfer.endDate ?? Date()

            // Check if time ranges overlap
            let startsClose = abs(sessionStart.timeIntervalSince(transferStart)) < tolerance
            let endsClose = abs(sessionEnd.timeIntervalSince(transferEnd)) < tolerance

            if startsClose && endsClose {
                watchLogger.warning("⚠️ Potential duplicate session detected: \(session.id)")
                return session
            }
        }

        return nil
    }

    @MainActor
    private func handleWatchSession(_ transfer: SessionTransfer) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        do {
            let engine = GamificationEngine(modelContext: modelContext)
            let sessionDate = transfer.endDate ?? transfer.startDate
            let shouldCount = transfer.countsTowardStats

            // Track XP difference if updating
            var xpDelta = 0
            var xpForActivity = 0
            var sessionToMarkAwarded: ReadingSession? // Track session for xpAwarded flag

            // Check if session already exists by ID
            let descriptor = FetchDescriptor<ReadingSession>(
                predicate: #Predicate<ReadingSession> { session in
                    session.id == transfer.id
                }
            )
            let existingSessions = try modelContext.fetch(descriptor)

            var bookForSession: Book?

            if let existingSession = existingSessions.first {
                // Update existing session
                let previousXP = existingSession.xpEarned
                existingSession.startDate = transfer.startDate
                existingSession.endDate = transfer.endDate
                existingSession.startPage = transfer.startPage
                existingSession.endPage = transfer.endPage
                existingSession.durationMinutes = transfer.durationMinutes
                existingSession.isAutoGenerated = transfer.isAutoGenerated
                existingSession.countsTowardStats = transfer.countsTowardStats
                existingSession.isImported = transfer.isImported
                if shouldCount {
                    existingSession.xpEarned = engine.calculateXP(for: existingSession)
                } else {
                    existingSession.xpEarned = transfer.xpEarned
                }
                bookForSession = existingSession.book

                // Calculate XP delta and only award the difference
                xpDelta = shouldCount ? (existingSession.xpEarned - previousXP) : 0
                xpForActivity = shouldCount ? existingSession.xpEarned : 0
                watchLogger.info("Updated existing session from Watch (XP delta: \(xpDelta))")
            } else {
                // CRITICAL: Check for duplicate sessions before creating new one
                if let duplicate = findDuplicateSession(for: transfer, in: modelContext) {
                    watchLogger.warning("🚫 Duplicate session detected - merging instead of creating new")

                    // Update the duplicate instead of creating new
                    let previousXP = duplicate.xpEarned
                    duplicate.endDate = transfer.endDate
                    duplicate.endPage = transfer.endPage
                    duplicate.durationMinutes = transfer.durationMinutes
                    duplicate.countsTowardStats = transfer.countsTowardStats
                    duplicate.isImported = transfer.isImported
                    if shouldCount {
                        duplicate.xpEarned = engine.calculateXP(for: duplicate)
                    } else {
                        duplicate.xpEarned = transfer.xpEarned
                    }
                    bookForSession = duplicate.book
                    xpDelta = shouldCount ? (duplicate.xpEarned - previousXP) : 0
                    xpForActivity = shouldCount ? duplicate.xpEarned : 0
                    watchLogger.info("Merged duplicate session (XP delta: \(xpDelta))")

                    try modelContext.save()

                    // Award only the delta
                    let profileDescriptor = FetchDescriptor<UserProfile>()
                    if shouldCount, let profile = try modelContext.fetch(profileDescriptor).first {
                        if xpDelta != 0 {
                            engine.awardXP(xpDelta, to: profile)
                        }
                        engine.updateStreak(for: profile, sessionDate: sessionDate)
                        engine.checkAchievements(for: profile)
                        try modelContext.save()
                    }
                    return
                }
                // Find the book
                let bookDescriptor = FetchDescriptor<Book>(
                    predicate: #Predicate<Book> { book in
                        book.id == transfer.bookId
                    }
                )
                let books = try modelContext.fetch(bookDescriptor)

                guard let book = books.first else {
                    watchLogger.warning("Book not found for Watch session: \(transfer.bookId)")
                    return
                }

                // Create new session
                let session = ReadingSession(
                    id: transfer.id,
                    startDate: transfer.startDate,
                    endDate: transfer.endDate,
                    startPage: transfer.startPage,
                    endPage: transfer.endPage,
                    durationMinutes: transfer.durationMinutes,
                    xpEarned: 0,
                    isAutoGenerated: transfer.isAutoGenerated,
                    countsTowardStats: transfer.countsTowardStats,
                    isImported: transfer.isImported,
                    book: book
                )
                if shouldCount {
                    session.xpEarned = engine.calculateXP(for: session)
                }
                session.xpAwarded = false // Will be set to true when XP is awarded below
                modelContext.insert(session)
                bookForSession = book
                xpDelta = shouldCount ? session.xpEarned : 0
                xpForActivity = shouldCount ? session.xpEarned : 0
                sessionToMarkAwarded = session // Mark this session after awarding XP
                watchLogger.info("Created new session from Watch: \(transfer.endPage - transfer.startPage) pages, \(session.xpEarned) XP")
            }

            // Align book progress to session
            if let book = bookForSession {
                let maxPages = book.totalPages ?? ReadingConstants.defaultMaxPages
                book.currentPage = min(maxPages, max(0, transfer.endPage))
                await ReadingSessionActivityManager.shared.updateActivity(
                    currentPage: book.currentPage,
                    xpEarned: xpForActivity
                )
            }

            try modelContext.save()

            // Update profile stats with authoritative calculation
            let profileDescriptor = FetchDescriptor<UserProfile>()
            if shouldCount, let profile = try modelContext.fetch(profileDescriptor).first {
                if xpDelta != 0 {
                    engine.awardXP(xpDelta, to: profile)

                    // CRITICAL: Mark session as awarded if this is a new session
                    if let session = sessionToMarkAwarded {
                        session.xpAwarded = true
                    }
                }
                engine.updateStreak(for: profile, sessionDate: sessionDate)
                engine.checkAchievements(for: profile)
                try modelContext.save()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                // Keep Watch in sync with latest stats
                sendProfileStatsToWatch(profile)
            }

            // Force UI refresh
            NotificationCenter.default.post(name: Notification.Name("watchSessionReceived"), object: nil)

            // If this session has an end date, end Live Activity to avoid stale state
            if transfer.endDate != nil {
                await ReadingSessionActivityManager.shared.endActivity()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            } else {
                await ReadingSessionActivityManager.shared.updateActivity(
                    currentPage: transfer.endPage,
                    xpEarned: xpForActivity
                )
            }
        } catch {
            watchLogger.error("Failed to handle Watch session: \(error)")
        }
    }

    @MainActor
    private func handleProfileSettings(_ settings: ProfileSettingsTransfer) async {
        guard let modelContext = modelContext else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(descriptor)

            if let profile = profiles.first {
                profile.hideAutoSessionsIPhone = settings.hideAutoSessionsIPhone
                profile.hideAutoSessionsWatch = settings.hideAutoSessionsWatch
                profile.showSettingsOnWatch = settings.showSettingsOnWatch
                profile.useCircularProgressWatch = settings.useCircularProgressWatch
                profile.themeColorRawValue = settings.themeColorRawValue
                profile.streaksPaused = settings.streaksPaused
                try modelContext.save()
                watchLogger.info("Updated profile settings from Watch")
            }
        } catch {
            watchLogger.error("Failed to update profile settings: \(error)")
        }
    }

    @MainActor
    private func handleProfileStats(_ stats: ProfileStatsTransfer) async {
        // iPhone is the source of truth for stats (Watch only creates/view sessions).
        // Ignore Watch-sent stats to prevent stale overrides after deletions/edits on iPhone.
        watchLogger.info("Ignoring profile stats from Watch (iPhone authoritative)")
    }

    // MARK: - Live Activity Handlers

    @MainActor
    private func handleLiveActivityStart(_ transfer: LiveActivityStartTransfer) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        do {
            // Prefer stable book ID; fall back to title if missing
            var book: Book?
            if let bookId = transfer.bookId {
                let descriptor = FetchDescriptor<Book>(
                    predicate: #Predicate<Book> { $0.id == bookId }
                )
                book = try modelContext.fetch(descriptor).first
            }

            if book == nil {
                let descriptor = FetchDescriptor<Book>(
                    predicate: #Predicate<Book> { $0.title == transfer.bookTitle }
                )
                book = try modelContext.fetch(descriptor).first
            }

            guard let book else {
                watchLogger.warning("Book not found for Live Activity: \(transfer.bookTitle)")
                return
            }

            // Get theme color from profile
            let profileDescriptor = FetchDescriptor<UserProfile>()
            let profile = try? modelContext.fetch(profileDescriptor).first
            let themeHex = profile?.themeColor.color.toHex() ?? "#00CED1"

            // Start Live Activity with the authoritative baseline from Watch
            await ReadingSessionActivityManager.shared.startActivity(
                book: book,
                currentPage: transfer.currentPage,
                startPage: transfer.startPage,
                startTime: transfer.startTime,
                themeColorHex: themeHex
            )
            watchLogger.info("✅ Started Live Activity from Watch: \(transfer.bookTitle)")
        } catch {
            watchLogger.error("Failed to start Live Activity from Watch: \(error)")
        }
    }

    @MainActor
    private func handleLiveActivityUpdate(_ transfer: LiveActivityUpdateTransfer) async {
        await ReadingSessionActivityManager.shared.updateActivity(
            currentPage: transfer.currentPage,
            xpEarned: transfer.xpEarned
        )
        // Export widget snapshot so widgets/Dynamic Island reflect the latest page/XP
        if let modelContext = modelContext {
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        }
        watchLogger.info("Updated Live Activity from Watch: Page \(transfer.currentPage)")
    }

    @MainActor
    private func handleLiveActivityState(_ transfer: LiveActivityStateTransfer) async {
        let clockSkewTolerance: TimeInterval = 300
        if let last = lastLiveActivityStateTimestamp, transfer.timestamp <= last {
            let drift = abs(transfer.timestamp.timeIntervalSince(last))
            if drift > clockSkewTolerance {
                watchLogger.info("Ignoring stale Live Activity state update")
                return
            }
        }

        if let last = lastLiveActivityStateTimestamp {
            lastLiveActivityStateTimestamp = max(last, transfer.timestamp)
        } else {
            lastLiveActivityStateTimestamp = transfer.timestamp
        }

        if transfer.isPaused {
            await ReadingSessionActivityManager.shared.pauseActivity()
            watchLogger.info("⏸️ Paused Live Activity from Watch")
        } else {
            await ReadingSessionActivityManager.shared.resumeActivity()
            watchLogger.info("▶️ Resumed Live Activity from Watch")
        }
    }

    @MainActor
    private func handleLiveActivityEnd() async {
        await ReadingSessionActivityManager.shared.endActivity()
        if let modelContext = resolvedModelContext() {
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        }
        watchLogger.info("🛑 Ended Live Activity from Watch")
    }

    // MARK: - Active Session Handlers

    @MainActor
    private func handleActiveSession(_ transfer: ActiveSessionTransfer) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        let receiveDate = Date()
        let clockSkewTolerance: TimeInterval = 300
        let rawOffset = receiveDate.timeIntervalSince(transfer.sentAt)
        let timeOffset = abs(rawOffset) <= clockSkewTolerance ? rawOffset : 0
        let adjustedPausedAt = transfer.pausedAt?.addingTimeInterval(timeOffset)
        let safePausedAt = adjustedPausedAt.map { min($0, receiveDate) }
        let clampedPausedDuration = max(0, transfer.totalPausedDuration)
        let adjustedStartDate = transfer.startDate.addingTimeInterval(timeOffset)
        var liveActivityStartDate = adjustedStartDate

        if let lastEnd = lastActiveSessionEndDate, transfer.lastUpdated <= lastEnd {
            let drift = abs(lastEnd.timeIntervalSince(transfer.lastUpdated))
            if drift > clockSkewTolerance && adjustedStartDate <= lastEnd {
                watchLogger.info("Ignoring stale active session update (ended at \(lastEnd))")
                return
            }
        }

        if endedActiveSessionIDs[transfer.id] != nil {
            watchLogger.info("Ignoring active session update for ended id \(transfer.id)")
            return
        }

        do {
            // Fetch existing sessions
            let descriptor = FetchDescriptor<ActiveReadingSession>()
            let existingSessions = try modelContext.fetch(descriptor)

            // Check if we have an existing session with the same ID
            if let existingSession = existingSessions.first(where: { $0.id == transfer.id }) {
                // Drop stale updates that arrive out of order (tolerate clock skew for state changes)
                let isStale = transfer.lastUpdated <= existingSession.lastUpdated
                let stateChanged = transfer.isPaused != existingSession.isPaused ||
                    transfer.currentPage != existingSession.currentPage ||
                    transfer.totalPausedDuration != existingSession.totalPausedDuration
                if isStale {
                    let drift = abs(transfer.lastUpdated.timeIntervalSince(existingSession.lastUpdated))
                    if !(stateChanged && drift <= clockSkewTolerance) {
                        watchLogger.info("Ignoring stale active session update from Watch (existing newer)")
                        return
                    }
                    watchLogger.info("Accepting state change despite clock drift (\(Int(drift))s)")
                }

                // UPDATE in place
                let maxPages = existingSession.book?.totalPages ?? ReadingConstants.defaultMaxPages
                let clampedPage = min(maxPages, max(0, transfer.currentPage))
                let maxPausedDuration = max(0, receiveDate.timeIntervalSince(existingSession.startDate))
                existingSession.currentPage = clampedPage
                existingSession.isPaused = transfer.isPaused
                existingSession.pausedAt = safePausedAt.map { max($0, existingSession.startDate) }
                existingSession.totalPausedDuration = min(clampedPausedDuration, maxPausedDuration)
                existingSession.lastUpdated = max(existingSession.lastUpdated, transfer.lastUpdated)
                existingSession.book?.currentPage = clampedPage
                watchLogger.info("✅ Updated session from Watch: \(transfer.pagesRead) pages")
                liveActivityStartDate = existingSession.startDate

                // Force immediate widget update
                try? modelContext.save()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            } else {
                // ENFORCE SINGLE SESSION: Delete all existing sessions before creating new one
                for oldSession in existingSessions {
                    watchLogger.info("🧹 Deleting old active session \(oldSession.id) to enforce single session")
                    modelContext.delete(oldSession)
                }
                // Find the book
                let bookDescriptor = FetchDescriptor<Book>(
                    predicate: #Predicate<Book> { book in
                        book.id == transfer.bookId
                    }
                )
                let books = try modelContext.fetch(bookDescriptor)

                guard let book = books.first else {
                    watchLogger.warning("Book not found: \(transfer.bookId)")
                    return
                }

                // Create NEW session only if none exists
                let maxPages = book.totalPages ?? ReadingConstants.defaultMaxPages
                let clampedPage = min(maxPages, max(0, transfer.currentPage))
                let maxPausedDuration = max(0, receiveDate.timeIntervalSince(adjustedStartDate))
                let activeSession = ActiveReadingSession(
                    id: transfer.id,
                    book: book,
                    startDate: adjustedStartDate,
                    currentPage: clampedPage,
                    startPage: transfer.startPage,
                    isPaused: transfer.isPaused,
                    pausedAt: safePausedAt.map { max($0, adjustedStartDate) },
                    totalPausedDuration: min(clampedPausedDuration, maxPausedDuration),
                    lastUpdated: transfer.lastUpdated,
                    sourceDevice: transfer.sourceDevice
                )
                modelContext.insert(activeSession)
                book.currentPage = clampedPage
                watchLogger.info("✅ Created session from Watch: \(transfer.pagesRead) pages")
            }

            // Update Live Activity FIRST (real-time)
            await ReadingSessionActivityManager.shared.syncActivityState(
                startTime: liveActivityStartDate,
                startPage: transfer.startPage,
                currentPage: transfer.currentPage,
                totalPausedDuration: min(clampedPausedDuration, max(0, receiveDate.timeIntervalSince(liveActivityStartDate))),
                pausedAt: safePausedAt.map { max($0, liveActivityStartDate) },
                isPaused: transfer.isPaused,
                xpEarned: 0
            )

            // Then save and update widgets (best-effort)
            try modelContext.save()
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)

            // Post notification to update UI
            NotificationCenter.default.post(name: Notification.Name("watchSessionReceived"), object: nil)
        } catch {
            watchLogger.error("Failed to handle active session: \(error)")
        }
    }

    @MainActor
    private func handleActiveSessionEnd(endedId: UUID? = nil) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        do {
            // Delete all active sessions
            let descriptor = FetchDescriptor<ActiveReadingSession>()
            let activeSessions = try modelContext.fetch(descriptor)

            for session in activeSessions {
                endedActiveSessionIDs[session.id] = Date()
                modelContext.delete(session)
            }

            try modelContext.save()
            watchLogger.info("Ended all active sessions from Watch")
            lastActiveSessionEndDate = Date()

            // Remember explicitly-ended id even if none existed locally
            if let endedId {
                endedActiveSessionIDs[endedId] = Date()
            }

            // End Live Activity and refresh widgets
            await ReadingSessionActivityManager.shared.endActivity()
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)

            // Post notification to update UI
            NotificationCenter.default.post(name: Notification.Name("watchSessionReceived"), object: nil)
        } catch {
            watchLogger.error("Failed to end active sessions: \(error)")
        }
    }

    /// Handles consolidated session completion from Watch (ATOMIC - replaces separate handling)
    /// Validate session completion data before processing
    private func validateSessionCompletion(_ completion: SessionCompletionTransfer) -> Bool {
        let session = completion.completedSession

        // Validate dates
        if let endDate = session.endDate {
            // endDate should be >= startDate
            guard endDate >= session.startDate else {
                watchLogger.error("⚠️ Invalid session: endDate < startDate")
                return false
            }

            // endDate should not be too far in future (5 min tolerance)
            let maxFuture = Date().addingTimeInterval(300)
            guard endDate <= maxFuture else {
                watchLogger.error("⚠️ Invalid session: endDate in future")
                return false
            }

            // For completed sessions ending recently (< 5 min ago), process normally
            // For older sessions, log warning but still process (late sync is OK)
            let timeSinceEnd = Date().timeIntervalSince(endDate)
            if timeSinceEnd > 3600 { // 1 hour
                watchLogger.info("ℹ️ Processing old session (ended \(Int(timeSinceEnd/60)) min ago)")
            }
        }

        // Validate pages are reasonable
        guard session.startPage >= 0 && session.endPage >= 0 else {
            watchLogger.error("⚠️ Invalid session: negative pages")
            return false
        }

        // Validate duration is reasonable (< 24 hours)
        guard session.durationMinutes >= 0 && session.durationMinutes < 1440 else {
            watchLogger.error("⚠️ Invalid session: duration out of range")
            return false
        }

        return true
    }

    @MainActor
    private func handleSessionCompletion(_ completion: SessionCompletionTransfer) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        // VALIDATION: Ensure completion data is valid before processing
        guard validateSessionCompletion(completion) else {
            watchLogger.error("❌ Session completion validation failed, ignoring")
            return
        }

        watchLogger.info("🎯 Processing atomic session completion from Watch")

        // 1. End active session
        endedActiveSessionIDs[completion.activeSessionId] = Date()
        do {
            let descriptor = FetchDescriptor<ActiveReadingSession>(
                predicate: #Predicate<ActiveReadingSession> { session in
                    session.id == completion.activeSessionId
                }
            )
            let activeSessions = try modelContext.fetch(descriptor)
            for session in activeSessions {
                modelContext.delete(session)
                watchLogger.info("✅ Deleted active session: \(completion.activeSessionId)")
            }
        } catch {
            watchLogger.error("Failed to delete active session: \(error)")
        }

        // 2. Process completed session (includes ending Live Activity if session has endDate)
        await handleWatchSession(completion.completedSession)

        // 3. Export snapshot and notify UI
        WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        NotificationCenter.default.post(name: Notification.Name("watchSessionReceived"), object: nil)

        watchLogger.info("✅ Atomic session completion handled successfully")
    }

    @MainActor
    private func handleBookPosition(_ transfer: BookPositionTransfer) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        do {
            // Find the book
            let bookDescriptor = FetchDescriptor<Book>(
                predicate: #Predicate<Book> { book in
                    book.id == transfer.bookId
                }
            )
            let books = try modelContext.fetch(bookDescriptor)

            guard let book = books.first else {
                watchLogger.warning("Book not found for position: \(transfer.bookId)")
                return
            }

            // Create or update position
            let position = BookPosition(
                book: book,
                pageNumber: transfer.pageNumber,
                lineNumber: transfer.lineNumber,
                timestamp: transfer.timestamp,
                note: transfer.note
            )
            position.id = transfer.id

            modelContext.insert(position)

            if book.bookPositions == nil {
                book.bookPositions = []
            }
            book.bookPositions?.append(position)

            try modelContext.save()
            watchLogger.info("✅ Saved book position from Watch: Page \(transfer.pageNumber)")
        } catch {
            watchLogger.error("Failed to handle book position: \(error)")
        }
    }

    @MainActor
    private func handleQuotes(_ transfers: [QuoteTransfer]) async {
        guard let modelContext = resolvedModelContext() else {
            watchLogger.warning("ModelContext not configured")
            return
        }

        do {
            for transfer in transfers {
                // Find the book
                let bookDescriptor = FetchDescriptor<Book>(
                    predicate: #Predicate<Book> { book in
                        book.id == transfer.bookId
                    }
                )
                let books = try modelContext.fetch(bookDescriptor)

                guard let book = books.first else {
                    watchLogger.warning("Book not found for quote: \(transfer.bookId)")
                    continue
                }

                // Create quote
                let quote = Quote(
                    book: book,
                    text: transfer.text,
                    pageNumber: transfer.pageNumber,
                    note: transfer.note,
                    isFavorite: transfer.isFavorite
                )
                quote.id = transfer.id
                quote.dateAdded = transfer.dateAdded

                modelContext.insert(quote)

                if book.quotes == nil {
                    book.quotes = []
                }
                book.quotes?.append(quote)
            }

            try modelContext.save()
            watchLogger.info("✅ Saved \(transfers.count) quotes from Watch")
        } catch {
            watchLogger.error("Failed to handle quotes: \(error)")
        }
    }
}

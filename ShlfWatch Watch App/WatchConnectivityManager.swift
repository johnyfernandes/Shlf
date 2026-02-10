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
// Transfer models provided by Shared/ConnectivityTransfers.swift

private enum ReadingConstants {
    static let defaultMaxPages = 1000
}

class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shlf.watch", category: "WatchSync")
    static let languageOverrideKey = "languageOverride"
    static let phoneLanguageOverrideStorageKey = "phoneLanguageOverride"
    private var modelContext: ModelContext?
    private var lastActiveSessionEndDate: Date?
    private var endedActiveSessionIDs: [UUID: Date] = [:] // Track UUID -> timestamp when ended
    private var lastPageUpdateTimestamps: [UUID: Date] = [:]
    private let pendingSessionIdsKey = "pendingSessionIds"
    private var pendingSessionIds: Set<UUID> = []
    private let pendingSessionIdsLock = NSLock()

    // MARK: - Live Activity Handlers
    @MainActor
    private func handleLiveActivityEnd() async {
        await ReadingSessionActivityManager.shared.endActivity()
        Self.logger.info("🛑 Ended Live Activity from iPhone")
    }

    private override init() {
        super.init()
        loadPendingSessionIds()

        // Schedule periodic cleanup of old endedActiveSessionIDs (every hour)
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.cleanupOldEndedSessionIDs()
        }
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
            Self.logger.info("🧹 Cleaned up \(removedCount) old ended session IDs (kept \(self.endedActiveSessionIDs.count))")
        }
    }

    private func storePhoneLanguageOverride(_ rawValue: String) {
        UserDefaults.standard.set(rawValue, forKey: Self.phoneLanguageOverrideStorageKey)
        Self.logger.info("🌐 Stored phone language override: \(rawValue)")
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

    private func loadPendingSessionIds() {
        let stored = UserDefaults.standard.array(forKey: pendingSessionIdsKey) as? [String] ?? []
        pendingSessionIdsLock.lock()
        pendingSessionIds = Set(stored.compactMap(UUID.init))
        pendingSessionIdsLock.unlock()
    }

    private func persistPendingSessionIdsLocked() {
        let stored = pendingSessionIds.map { $0.uuidString }
        UserDefaults.standard.set(stored, forKey: pendingSessionIdsKey)
    }

    private func insertPendingSessionId(_ id: UUID) {
        pendingSessionIdsLock.lock()
        pendingSessionIds.insert(id)
        persistPendingSessionIdsLocked()
        pendingSessionIdsLock.unlock()
    }

    private func removePendingSessionId(_ id: UUID) -> Bool {
        pendingSessionIdsLock.lock()
        let removed = pendingSessionIds.remove(id) != nil
        if removed {
            persistPendingSessionIdsLocked()
        }
        pendingSessionIdsLock.unlock()
        return removed
    }

    private func removePendingSessionIds(_ ids: [UUID]) -> Int {
        pendingSessionIdsLock.lock()
        var removedCount = 0
        for id in ids {
            if pendingSessionIds.remove(id) != nil {
                removedCount += 1
            }
        }
        if removedCount > 0 {
            persistPendingSessionIdsLocked()
        }
        pendingSessionIdsLock.unlock()
        return removedCount
    }

    private func subtractPendingSessionIds(_ ids: Set<UUID>) -> Int {
        pendingSessionIdsLock.lock()
        let before = pendingSessionIds.count
        pendingSessionIds.subtract(ids)
        let removedCount = before - pendingSessionIds.count
        if removedCount > 0 {
            persistPendingSessionIdsLocked()
        }
        pendingSessionIdsLock.unlock()
        return removedCount
    }

    private func snapshotPendingSessionIds() -> Set<UUID> {
        pendingSessionIdsLock.lock()
        let snapshot = pendingSessionIds
        pendingSessionIdsLock.unlock()
        return snapshot
    }

    func sendPageDelta(_ delta: PageDelta) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        do {
            let data = try JSONEncoder().encode(delta)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["pageDelta": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        Self.logger.error("Failed to send page delta: \(error)")
                        // Fallback to guaranteed delivery
                        WCSession.default.transferUserInfo(["pageDelta": data])
                        Self.logger.info("↩️ Queued page delta (fallback): \(delta.delta)")
                    }
                )
                Self.logger.info("📤 Sent page delta (instant): \(delta.delta)")
            } else {
                WCSession.default.transferUserInfo(["pageDelta": data])
                Self.logger.info("📦 Queued page delta (guaranteed): \(delta.delta)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendSessionToPhone(_ session: ReadingSession) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        guard let bookId = session.book?.id else {
            Self.logger.warning("Session has no book")
            return
        }

        do {
            insertPendingSessionId(session.id)

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
                        Self.logger.error("Failed to send session: \(error)")
                        // CRITICAL: Fallback to guaranteed delivery to ensure Live Activity ends
                        WCSession.default.transferUserInfo(["session": data])
                        Self.logger.info("↩️ Queued session (fallback): \(session.endPage - session.startPage) pages, \(session.xpEarned) XP")
                    }
                )
                Self.logger.info("📤 Sent session to iPhone (instant): \(session.endPage - session.startPage) pages, \(session.xpEarned) XP")
            } else {
                WCSession.default.transferUserInfo(["session": data])
                Self.logger.info("📦 Queued session to iPhone (guaranteed): \(session.endPage - session.startPage) pages, \(session.xpEarned) XP")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendProfileSettingsToPhone(_ profile: UserProfile) {
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
                        Self.logger.error("Failed to send profile settings: \(error)")
                        // Fallback to guaranteed delivery
                        WCSession.default.transferUserInfo(["profileSettings": data])
                        Self.logger.info("↩️ Queued profile settings (fallback)")
                    }
                )
                Self.logger.info("📤 Sent profile settings to iPhone (instant)")
            } else {
                WCSession.default.transferUserInfo(["profileSettings": data])
                Self.logger.info("📦 Queued profile settings to iPhone (guaranteed)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendProfileStatsToPhone(_ profile: UserProfile) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let transfer = ProfileStatsTransfer(
                totalXP: profile.totalXP,
                currentStreak: profile.currentStreak,
                longestStreak: profile.longestStreak,
                lastReadingDate: profile.lastReadingDate
            )
            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["profileStats": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        Self.logger.error("Failed to send profile stats: \(error)")
                        // Fallback to guaranteed delivery
                        WCSession.default.transferUserInfo(["profileStats": data])
                        Self.logger.info("↩️ Queued profile stats (fallback): XP=\(profile.totalXP), Streak=\(profile.currentStreak)")
                    }
                )
                Self.logger.info("📤 Sent profile stats to iPhone (instant): XP=\(profile.totalXP), Streak=\(profile.currentStreak)")
            } else {
                WCSession.default.transferUserInfo(["profileStats": data])
                Self.logger.info("📦 Queued profile stats to iPhone (guaranteed): XP=\(profile.totalXP), Streak=\(profile.currentStreak)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    // MARK: - Active Session Sync

    func sendActiveSessionToPhone(_ activeSession: ActiveReadingSession) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        guard let bookId = activeSession.book?.id else {
            Self.logger.warning("Cannot send active session without book")
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
                        Self.logger.error("Failed to send active session: \(error)")
                        WCSession.default.transferUserInfo(["activeSession": data])
                        Self.logger.info("↩️ Queued active session (fallback): \(activeSession.pagesRead) pages")
                    }
                )
                Self.logger.info("📤 Sent active session (instant): \(activeSession.pagesRead) pages")
            } else {
                // Guaranteed delivery when phone is backgrounded/unreachable
                WCSession.default.transferUserInfo(["activeSession": data])
                Self.logger.info("📦 Queued active session (guaranteed): \(activeSession.pagesRead) pages")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendActiveSessionEndToPhone(activeSessionId: UUID? = nil) {
        guard WCSession.default.activationState == .activated else { return }

        var payload: [String: Any] = ["activeSessionEnd": true]
        if let id = activeSessionId {
            payload["activeSessionEndId"] = id.uuidString
            endedActiveSessionIDs[id] = Date()
        }

        // Use transferUserInfo to avoid blocking and guarantee delivery
        WCSession.default.transferUserInfo(payload)
        Self.logger.info("📦 Queued active session end (guaranteed)")
    }

    /// Sends a consolidated session completion message (PREFERRED over separate messages)
    /// Combines activeSessionEnd, completedSession, and liveActivityEnd into a single atomic transfer
    func sendSessionCompletionToPhone(activeSessionId: UUID, completedSession: ReadingSession) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        guard let bookId = completedSession.book?.id else {
            Self.logger.warning("Session has no book")
            return
        }

        do {
            insertPendingSessionId(completedSession.id)

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

            Self.logger.info("📦 Queued session completion (atomic): \(completedSession.endPage - completedSession.startPage) pages, \(completedSession.xpEarned) XP")
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendBookPositionToPhone(_ position: BookPosition) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        guard let bookId = position.book?.id else {
            Self.logger.warning("Cannot send position without book")
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
                        Self.logger.error("Failed to send position to iPhone: \(error)")
                        WCSession.default.transferUserInfo(["bookPosition": data])
                        Self.logger.info("↩️ Queued position (fallback): Page \(position.pageNumber)")
                    }
                )
                Self.logger.info("📤 Sent position to iPhone (instant): Page \(position.pageNumber)")
            } else {
                WCSession.default.transferUserInfo(["bookPosition": data])
                Self.logger.info("📦 Queued position to iPhone (guaranteed): Page \(position.pageNumber)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    // MARK: - Live Activity Sync

    func sendLiveActivityStart(bookId: UUID?, bookTitle: String, bookAuthor: String, totalPages: Int, startPage: Int, currentPage: Int, startTime: Date) {
        guard WCSession.default.activationState == .activated else {
            Self.logger.warning("WC not activated")
            return
        }

        do {
            let transfer = LiveActivityStartTransfer(
                bookId: bookId,
                bookTitle: bookTitle,
                bookAuthor: bookAuthor,
                totalPages: totalPages,
                startPage: startPage,
                currentPage: currentPage,
                startTime: startTime
            )
            let data = try JSONEncoder().encode(transfer)

            // Use sendMessage for instant delivery if reachable
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["liveActivityStart": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        Self.logger.error("Failed to send Live Activity start: \(error)")
                        // Fallback to transferUserInfo if sendMessage fails
                        WCSession.default.transferUserInfo(["liveActivityStart": data])
                    }
                )
                Self.logger.info("📤 Sent Live Activity start (instant): \(bookTitle)")
            } else {
                // Use transferUserInfo for guaranteed delivery even when iPhone is backgrounded
                WCSession.default.transferUserInfo(["liveActivityStart": data])
                Self.logger.info("📦 Queued Live Activity start (guaranteed): \(bookTitle)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendLiveActivityUpdate(currentPage: Int, xpEarned: Int) {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let transfer = LiveActivityUpdateTransfer(currentPage: currentPage, xpEarned: xpEarned)
            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["liveActivityUpdate": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        Self.logger.error("Failed to send Live Activity update: \(error)")
                        WCSession.default.transferUserInfo(["liveActivityUpdate": data])
                        Self.logger.info("↩️ Queued Live Activity update after failure")
                    }
                )
                Self.logger.info("📤 Sent Live Activity update: page \(currentPage), XP \(xpEarned)")
            } else {
                // Use transferUserInfo so frequent updates don't hitch the UI and still arrive if unreachable.
                WCSession.default.transferUserInfo(["liveActivityUpdate": data])
                Self.logger.info("📦 Queued Live Activity update: page \(currentPage), XP \(xpEarned)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendLiveActivityPause() {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let transfer = LiveActivityStateTransfer(isPaused: true)
            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["liveActivityState": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        Self.logger.error("Failed to send Live Activity pause: \(error)")
                        WCSession.default.transferUserInfo(["liveActivityState": data])
                        Self.logger.info("↩️ Queued Live Activity pause")
                    }
                )
                Self.logger.info("Sent Live Activity pause to iPhone")
            } else {
                WCSession.default.transferUserInfo(["liveActivityState": data])
                Self.logger.info("📦 Queued Live Activity pause (unreachable)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendLiveActivityResume() {
        guard WCSession.default.activationState == .activated else { return }

        do {
            let transfer = LiveActivityStateTransfer(isPaused: false)
            let data = try JSONEncoder().encode(transfer)
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["liveActivityState": data],
                    replyHandler: nil,
                    errorHandler: { error in
                        Self.logger.error("Failed to send Live Activity resume: \(error)")
                        WCSession.default.transferUserInfo(["liveActivityState": data])
                        Self.logger.info("↩️ Queued Live Activity resume")
                    }
                )
                Self.logger.info("Sent Live Activity resume to iPhone")
            } else {
                WCSession.default.transferUserInfo(["liveActivityState": data])
                Self.logger.info("📦 Queued Live Activity resume (unreachable)")
            }
        } catch {
            Self.logger.error("Encoding error: \(error)")
        }
    }

    func sendLiveActivityEnd() {
        guard WCSession.default.activationState == .activated else { return }

        let payload: [String: Any] = ["liveActivityEnd": true]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                payload,
                replyHandler: nil,
                errorHandler: { error in
                    Self.logger.error("Failed to send Live Activity end: \(error)")
                    WCSession.default.transferUserInfo(payload)
                    Self.logger.info("↩️ Queued Live Activity end")
                }
            )
            Self.logger.info("Sent Live Activity end to iPhone")
        } else {
            WCSession.default.transferUserInfo(payload)
            Self.logger.info("📦 Queued Live Activity end")
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
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Self.logger.info("Watch received message")

        if let languageOverride = message[Self.languageOverrideKey] as? String {
            Task { @MainActor in
                self.storePhoneLanguageOverride(languageOverride)
            }
        }

        // Handle page delta from iPhone
        if let pageDeltaData = message["pageDelta"] as? Data {
            Task { @MainActor in
                do {
                    let delta = try JSONDecoder().decode(PageDelta.self, from: pageDeltaData)
                    Self.logger.info("Received page delta from iPhone: \(delta.delta)")
                    await self.handlePageDeltaFromPhone(delta)
                } catch {
                    Self.logger.error("Page delta decoding error: \(error)")
                }
            }
        }

        // Handle profile settings from iPhone
        if let profileData = message["profileSettings"] as? Data {
            Task { @MainActor in
                do {
                    let settings = try JSONDecoder().decode(ProfileSettingsTransfer.self, from: profileData)
                    Self.logger.info("Received profile settings from iPhone")
                    await self.handleProfileSettings(settings)
                } catch {
                    Self.logger.error("Profile settings decoding error: \(error)")
                }
            }
        }

        // Handle profile stats from iPhone
        if let statsData = message["profileStats"] as? Data {
            Task { @MainActor in
                do {
                    let stats = try JSONDecoder().decode(ProfileStatsTransfer.self, from: statsData)
                    Self.logger.info("Received profile stats from iPhone: XP=\(stats.totalXP), Streak=\(stats.currentStreak)")
                    await self.handleProfileStats(stats)
                } catch {
                    Self.logger.error("Profile stats decoding error: \(error)")
                }
            }
        }

        // Handle single session from iPhone (for immediate sync)
        if let sessionData = message["session"] as? Data {
            Task { @MainActor in
                do {
                    let sessionTransfer = try JSONDecoder().decode(SessionTransfer.self, from: sessionData)
                    Self.logger.info("Received session from iPhone: \(sessionTransfer.endPage - sessionTransfer.startPage) pages")
                    await self.handleSessionFromPhone(sessionTransfer)
                } catch {
                    Self.logger.error("Session decoding error: \(error)")
                }
            }
        }

        // Handle session deletion from iPhone
        if let deletionData = message["sessionDeletion"] as? Data {
            Task { @MainActor in
                do {
                    let sessionIds = try JSONDecoder().decode([UUID].self, from: deletionData)
                    Self.logger.info("Received session deletion from iPhone: \(sessionIds.count) session(s)")
                    await self.handleSessionDeletion(sessionIds)
                } catch {
                    Self.logger.error("Session deletion decoding error: \(error)")
                }
            }
        }

        // Handle active session from iPhone
        if let activeSessionData = message["activeSession"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(ActiveSessionTransfer.self, from: activeSessionData)
                    Self.logger.info("Received active session from iPhone: \(transfer.pagesRead) pages")
                    await self.handleActiveSession(transfer)
                } catch {
                    Self.logger.error("Active session decoding error: \(error)")
                }
            }
        }

        // Handle active session end from iPhone
        if message["activeSessionEnd"] != nil {
            Task { @MainActor in
                let idString = message["activeSessionEndId"] as? String
                await self.handleActiveSessionEnd(endedId: idString.flatMap(UUID.init))
            }
        }

        // Handle Live Activity pause/resume from iPhone
        if let liveActivityData = message["liveActivityState"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityStateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityState(transfer)
                } catch {
                    Self.logger.error("Live Activity state decoding error: \(error)")
                }
            }
        }

        // ✅ Handle consolidated session completion from iPhone (PREFERRED)
        if let completionData = message["sessionCompletion"] as? Data {
            Task { @MainActor in
                do {
                    let completion = try JSONDecoder().decode(SessionCompletionTransfer.self, from: completionData)
                    Self.logger.info("✅ Received atomic session completion from iPhone: \(completion.completedSession.endPage - completion.completedSession.startPage) pages")
                    await self.handleSessionCompletion(completion)
                } catch {
                    Self.logger.error("Session completion decoding error: \(error)")
                }
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Self.logger.info("Watch received userInfo payload")

        if let languageOverride = userInfo[Self.languageOverrideKey] as? String {
            Task { @MainActor in
                self.storePhoneLanguageOverride(languageOverride)
            }
        }

        if let pageDeltaData = userInfo["pageDelta"] as? Data {
            Task { @MainActor in
                do {
                    let delta = try JSONDecoder().decode(PageDelta.self, from: pageDeltaData)
                    Self.logger.info("Received queued page delta from iPhone: \(delta.delta)")
                    await self.handlePageDeltaFromPhone(delta)
                } catch {
                    Self.logger.error("Page delta userInfo decoding error: \(error)")
                }
            }
        }

        if let profileData = userInfo["profileSettings"] as? Data {
            Task { @MainActor in
                do {
                    let settings = try JSONDecoder().decode(ProfileSettingsTransfer.self, from: profileData)
                    Self.logger.info("Received queued profile settings from iPhone")
                    await self.handleProfileSettings(settings)
                } catch {
                    Self.logger.error("Profile settings userInfo decoding error: \(error)")
                }
            }
        }

        if let statsData = userInfo["profileStats"] as? Data {
            Task { @MainActor in
                do {
                    let stats = try JSONDecoder().decode(ProfileStatsTransfer.self, from: statsData)
                    Self.logger.info("Received queued profile stats from iPhone: XP=\(stats.totalXP), Streak=\(stats.currentStreak)")
                    await self.handleProfileStats(stats)
                } catch {
                    Self.logger.error("Profile stats userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity update from iPhone
        if let liveActivityData = userInfo["liveActivityUpdate"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityUpdateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityUpdate(transfer)
                } catch {
                    Self.logger.error("Live Activity update userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity pause/resume from iPhone
        if let liveActivityData = userInfo["liveActivityState"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(LiveActivityStateTransfer.self, from: liveActivityData)
                    await self.handleLiveActivityState(transfer)
                } catch {
                    Self.logger.error("Live Activity state userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued Live Activity end from iPhone
        if userInfo["liveActivityEnd"] != nil {
            Task { @MainActor in
                await self.handleLiveActivityEnd()
            }
        }

        if let sessionData = userInfo["session"] as? Data {
            Task { @MainActor in
                do {
                    let sessionTransfer = try JSONDecoder().decode(SessionTransfer.self, from: sessionData)
                    Self.logger.info("Received queued session from iPhone: \(sessionTransfer.endPage - sessionTransfer.startPage) pages")
                    await self.handleSessionFromPhone(sessionTransfer)
                } catch {
                    Self.logger.error("Session userInfo decoding error: \(error)")
                }
            }
        }

        if let deletionData = userInfo["sessionDeletion"] as? Data {
            Task { @MainActor in
                do {
                    let sessionIds = try JSONDecoder().decode([UUID].self, from: deletionData)
                    Self.logger.info("Received queued session deletion from iPhone: \(sessionIds.count) session(s)")
                    await self.handleSessionDeletion(sessionIds)
                } catch {
                    Self.logger.error("Session deletion userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued active session from iPhone
        if let activeSessionData = userInfo["activeSession"] as? Data {
            Task { @MainActor in
                do {
                    let transfer = try JSONDecoder().decode(ActiveSessionTransfer.self, from: activeSessionData)
                    Self.logger.info("📦 Received queued active session from iPhone: \(transfer.pagesRead) pages")
                    await self.handleActiveSession(transfer)
                } catch {
                    Self.logger.error("Active session userInfo decoding error: \(error)")
                }
            }
        }

        // Handle queued active session end from iPhone
        if userInfo["activeSessionEnd"] != nil {
            Task { @MainActor in
                let idString = userInfo["activeSessionEndId"] as? String
                await self.handleActiveSessionEnd(endedId: idString.flatMap(UUID.init))
            }
        }

        // ✅ Handle queued consolidated session completion from iPhone (PREFERRED)
        if let completionData = userInfo["sessionCompletion"] as? Data {
            Task { @MainActor in
                do {
                    let completion = try JSONDecoder().decode(SessionCompletionTransfer.self, from: completionData)
                    Self.logger.info("✅📦 Received queued atomic session completion from iPhone: \(completion.completedSession.endPage - completion.completedSession.startPage) pages")
                    await self.handleSessionCompletion(completion)
                } catch {
                    Self.logger.error("Session completion userInfo decoding error: \(error)")
                }
            }
        }
    }

    @MainActor
    private func handleProfileSettings(_ settings: ProfileSettingsTransfer) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
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
                Self.logger.info("Updated profile settings from iPhone")
            }
        } catch {
            Self.logger.error("Failed to update profile settings: \(error)")
        }
    }

    @MainActor
    private func handleSessionFromPhone(_ transfer: SessionTransfer) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        do {
            // Ensure book exists
            let bookDescriptor = FetchDescriptor<Book>(
                predicate: #Predicate<Book> { book in
                    book.id == transfer.bookId
                }
            )
            let books = try modelContext.fetch(bookDescriptor)

            guard let book = books.first else {
                Self.logger.warning("Book not found for session: \(transfer.bookId)")
                return
            }

            // Check for existing session
            let sessionDescriptor = FetchDescriptor<ReadingSession>(
                predicate: #Predicate<ReadingSession> { session in
                    session.id == transfer.id
                }
            )
            let existing = try modelContext.fetch(sessionDescriptor)

            if let existingSession = existing.first {
                existingSession.startDate = transfer.startDate
                existingSession.endDate = transfer.endDate
                existingSession.startPage = transfer.startPage
                existingSession.endPage = transfer.endPage
                existingSession.durationMinutes = transfer.durationMinutes
                existingSession.xpEarned = transfer.xpEarned
                existingSession.isAutoGenerated = transfer.isAutoGenerated
                existingSession.countsTowardStats = transfer.countsTowardStats
                existingSession.isImported = transfer.isImported
            } else {
                let session = ReadingSession(
                    id: transfer.id,
                    startDate: transfer.startDate,
                    endDate: transfer.endDate,
                    startPage: transfer.startPage,
                    endPage: transfer.endPage,
                    durationMinutes: transfer.durationMinutes,
                    xpEarned: transfer.xpEarned,
                    isAutoGenerated: transfer.isAutoGenerated,
                    countsTowardStats: transfer.countsTowardStats,
                    isImported: transfer.isImported,
                    book: book
                )
                modelContext.insert(session)
            }

            // Align book progress
            let maxPages = book.totalPages ?? ReadingConstants.defaultMaxPages
            book.currentPage = min(maxPages, max(0, transfer.endPage))

            try modelContext.save()
            _ = removePendingSessionId(transfer.id)
            Self.logger.info("Applied session from iPhone to Watch: \(transfer.endPage - transfer.startPage) pages")
        } catch {
            Self.logger.error("Failed to handle session from iPhone: \(error)")
        }
    }

    @MainActor
    private func handleSessionDeletion(_ sessionIds: [UUID]) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        guard !sessionIds.isEmpty else { return }

        do {
            let descriptor = FetchDescriptor<ReadingSession>()
            let existingSessions = try modelContext.fetch(descriptor)
            let sessionsToDelete = existingSessions.filter { sessionIds.contains($0.id) }

            guard !sessionsToDelete.isEmpty else {
                Self.logger.info("No matching sessions to delete on Watch")
                return
            }

            for session in sessionsToDelete {
                modelContext.delete(session)
            }

            try modelContext.save()
            _ = removePendingSessionIds(sessionIds)
            Self.logger.info("🗑️ Deleted \(sessionsToDelete.count) session(s) on Watch")
        } catch {
            Self.logger.error("Failed to delete sessions on Watch: \(error)")
        }
    }

    @MainActor
    private func handleProfileStats(_ stats: ProfileStatsTransfer) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        do {
            let descriptor = FetchDescriptor<UserProfile>()
            let profiles = try modelContext.fetch(descriptor)

            if let profile = profiles.first {
                profile.totalXP = stats.totalXP
                profile.currentStreak = stats.currentStreak
                profile.longestStreak = stats.longestStreak
                profile.lastReadingDate = stats.lastReadingDate
                try modelContext.save()
                Self.logger.info("Updated profile stats from iPhone: XP=\(stats.totalXP), Streak=\(stats.currentStreak)")
            }
        } catch {
            Self.logger.error("Failed to update profile stats: \(error)")
        }
    }

    @MainActor
    private func handleLiveActivityUpdate(_ transfer: LiveActivityUpdateTransfer) async {
        // Live Activity runs on iPhone; Watch doesn't render it. Ignore but log for tracing.
        Self.logger.info("Received Live Activity update on Watch (ignored): page \(transfer.currentPage)")
    }

    @MainActor
    private func handleLiveActivityState(_ transfer: LiveActivityStateTransfer) async {
        // Live Activity UI stays on iPhone; Watch just logs for timeline tracing.
        Self.logger.info("Received Live Activity state on Watch (ignored): paused=\(transfer.isPaused)")
    }

    @MainActor
    private func handlePageDeltaFromPhone(_ delta: PageDelta) async {
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

            if let lastTimestamp = lastPageUpdateTimestamps[delta.bookUUID],
               delta.timestamp <= lastTimestamp {
                Self.logger.info("Ignoring stale page update for book \(delta.bookUUID)")
                return
            }
            lastPageUpdateTimestamps[delta.bookUUID] = delta.timestamp

            // Update current page
            let oldPage = book.currentPage
            let maxPages = book.totalPages ?? ReadingConstants.defaultMaxPages
            let targetPage = delta.newPage ?? (book.currentPage + delta.delta)
            book.currentPage = min(maxPages, max(0, targetPage))

            if let activeSession = (try? modelContext.fetch(FetchDescriptor<ActiveReadingSession>()))?
                .first(where: { $0.book?.id == book.id }) {
                activeSession.currentPage = book.currentPage
                activeSession.lastUpdated = max(activeSession.lastUpdated, delta.timestamp)
            }

            // Post notification so active timer sessions can update their state
            NotificationCenter.default.post(
                name: NSNotification.Name("PageDeltaFromPhone"),
                object: nil,
                userInfo: ["bookUUID": delta.bookUUID, "newPage": book.currentPage]
            )

            // Save context
            try modelContext.save()

            Self.logger.info("Updated book from iPhone: \(book.title) from page \(oldPage) to \(book.currentPage)")
        } catch {
            Self.logger.error("Failed to update book from iPhone delta: \(error)")
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Self.logger.info("Watch received application context")

        if let languageOverride = applicationContext[Self.languageOverrideKey] as? String {
            Task { @MainActor in
                self.storePhoneLanguageOverride(languageOverride)
            }
        }

        let booksData = applicationContext["books"] as? Data
        let sessionsData = applicationContext["sessions"] as? Data

        if booksData == nil && sessionsData == nil && applicationContext[Self.languageOverrideKey] == nil {
            Self.logger.warning("No data in context")
            return
        }

        Task { @MainActor in
            if let booksData = booksData {
                await self.handleBooksSync(booksData)
            }
            if let sessionsData = sessionsData {
                await self.handleSessionsSync(sessionsData)
            }
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

            let pendingSessionIds = snapshotPendingSessionIds()
            let sessionsDescriptor = FetchDescriptor<ReadingSession>()
            let existingSessions = try modelContext.fetch(sessionsDescriptor)
            let pendingBookIds: Set<UUID> = Set(existingSessions.compactMap { session in
                guard pendingSessionIds.contains(session.id) else { return nil }
                return session.book?.id
            })

            let activeSessionsDescriptor = FetchDescriptor<ActiveReadingSession>()
            let activeSessions = try modelContext.fetch(activeSessionsDescriptor)
            let activeBookIds: Set<UUID> = Set(activeSessions.compactMap { $0.book?.id })

            // Delete books that are no longer "Currently Reading" on iPhone
            // If a book has pending sessions, keep it but hide it from the reading list.
            for existingBook in existingBooks where !transferredUUIDs.contains(existingBook.id) {
                if activeBookIds.contains(existingBook.id) {
                    continue
                }
                if pendingBookIds.contains(existingBook.id) {
                    if existingBook.readingStatus != .wantToRead {
                        existingBook.readingStatus = .wantToRead
                    }
                    continue
                }
                modelContext.delete(existingBook)
                Self.logger.info("Removed book from Watch: \(existingBook.title) (no longer Currently Reading)")
            }

            try modelContext.save()
            Self.logger.info("✅ Synced \(bookTransfers.count) books to Watch")
        } catch {
            Self.logger.error("Failed to handle books sync: \(error)")
        }
    }

    @MainActor
    private func handleSessionsSync(_ sessionsData: Data) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        do {
            let sessionTransfers = try JSONDecoder().decode([SessionTransfer].self, from: sessionsData)
            Self.logger.info("Received \(sessionTransfers.count) sessions from iPhone")

            // Fetch existing sessions
            let descriptor = FetchDescriptor<ReadingSession>()
            let existingSessions = try modelContext.fetch(descriptor)

            // Create a map of existing sessions by UUID
            var existingSessionsMap = [UUID: ReadingSession]()
            for session in existingSessions {
                existingSessionsMap[session.id] = session
            }

            // Fetch all books to link sessions
            let booksDescriptor = FetchDescriptor<Book>()
            let allBooks = try modelContext.fetch(booksDescriptor)
            var booksMap = [UUID: Book]()
            for book in allBooks {
                booksMap[book.id] = book
            }

            // Update or insert sessions (MERGE, don't delete local sessions)
            let transferredSessionIds = Set(sessionTransfers.map { $0.id })
            for transfer in sessionTransfers {
                guard let book = booksMap[transfer.bookId] else {
                    Self.logger.warning("Book not found for session: \(transfer.bookId)")
                    continue
                }

                if let existingSession = existingSessionsMap[transfer.id] {
                    // Update existing session (iPhone data takes precedence)
                    existingSession.startDate = transfer.startDate
                    existingSession.endDate = transfer.endDate
                    existingSession.startPage = transfer.startPage
                    existingSession.endPage = transfer.endPage
                    existingSession.durationMinutes = transfer.durationMinutes
                    existingSession.xpEarned = transfer.xpEarned
                    existingSession.isAutoGenerated = transfer.isAutoGenerated
                    existingSession.countsTowardStats = transfer.countsTowardStats
                    existingSession.isImported = transfer.isImported
                    existingSession.book = book
                } else {
                    // Insert new session from iPhone
                    let session = ReadingSession(
                        id: transfer.id,
                        startDate: transfer.startDate,
                        endDate: transfer.endDate,
                        startPage: transfer.startPage,
                        endPage: transfer.endPage,
                        durationMinutes: transfer.durationMinutes,
                        xpEarned: transfer.xpEarned,
                        isAutoGenerated: transfer.isAutoGenerated,
                        countsTowardStats: transfer.countsTowardStats,
                        isImported: transfer.isImported,
                        book: book
                    )
                    modelContext.insert(session)
                }
            }

            _ = subtractPendingSessionIds(transferredSessionIds)

            // Prune sessions for currently reading books that no longer exist on iPhone.
            let trackedBookIds = Set(booksMap.keys)
            let pendingSnapshot = snapshotPendingSessionIds()
            let sessionsToDelete = existingSessions.filter { session in
                guard let bookId = session.book?.id else { return true }
                guard trackedBookIds.contains(bookId) else { return true }
                return !transferredSessionIds.contains(session.id) && !pendingSnapshot.contains(session.id)
            }

            if !sessionsToDelete.isEmpty {
                for session in sessionsToDelete {
                    modelContext.delete(session)
                }
                Self.logger.info("Pruned \(sessionsToDelete.count) stale session(s) from Watch sync")
            }

            try modelContext.save()
            Self.logger.info("Synced \(sessionTransfers.count) sessions to Watch")
        } catch {
            Self.logger.error("Failed to handle sessions sync: \(error)")
        }
    }

    // MARK: - Active Session Handlers

    @MainActor
    private func handleActiveSession(_ transfer: ActiveSessionTransfer) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
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

        // Ignore stale updates that arrive after an end message
        if let lastEnd = lastActiveSessionEndDate, transfer.lastUpdated <= lastEnd {
            let drift = abs(lastEnd.timeIntervalSince(transfer.lastUpdated))
            if drift > clockSkewTolerance && adjustedStartDate <= lastEnd {
                Self.logger.info("Ignoring stale active session update (ended at \(lastEnd))")
                return
            }
        }

        // Ignore updates for sessions we've explicitly ended
        if endedActiveSessionIDs[transfer.id] != nil {
            Self.logger.info("Ignoring active session update for ended id \(transfer.id)")
            return
        }

        do {
            // Fetch existing session
            let descriptor = FetchDescriptor<ActiveReadingSession>()
            let existingSessions = try modelContext.fetch(descriptor)

            if let existingSession = existingSessions.first(where: { $0.id == transfer.id }) {
                // UPDATE in place - don't delete!
                let isStale = transfer.lastUpdated <= existingSession.lastUpdated
                let stateChanged = transfer.isPaused != existingSession.isPaused ||
                    transfer.currentPage != existingSession.currentPage ||
                    transfer.totalPausedDuration != existingSession.totalPausedDuration
                if isStale {
                    let drift = abs(transfer.lastUpdated.timeIntervalSince(existingSession.lastUpdated))
                    if !(stateChanged && drift <= clockSkewTolerance) {
                        Self.logger.info("Ignoring stale active session update from iPhone (existing newer)")
                        return
                    }
                    Self.logger.info("Accepting state change despite clock drift (\(Int(drift))s)")
                }

                let maxPages = existingSession.book?.totalPages ?? ReadingConstants.defaultMaxPages
                let clampedPage = min(maxPages, max(0, transfer.currentPage))
                let maxPausedDuration = max(0, receiveDate.timeIntervalSince(existingSession.startDate))
                existingSession.currentPage = clampedPage
                existingSession.isPaused = transfer.isPaused
                existingSession.pausedAt = safePausedAt.map { max($0, existingSession.startDate) }
                existingSession.totalPausedDuration = min(clampedPausedDuration, maxPausedDuration)
                existingSession.lastUpdated = max(existingSession.lastUpdated, transfer.lastUpdated)
                existingSession.book?.currentPage = clampedPage
                Self.logger.info("✅ Updated session from iPhone: \(transfer.pagesRead) pages")
            } else {
                // ENFORCE SINGLE SESSION: Delete all existing sessions before creating new one
                for oldSession in existingSessions {
                    Self.logger.info("🧹 Deleting old active session \(oldSession.id) to enforce single session")
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
                    Self.logger.warning("Book not found: \(transfer.bookId)")
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
                Self.logger.info("✅ Created session from iPhone: \(transfer.pagesRead) pages")
            }

            try modelContext.save()
        } catch {
            Self.logger.error("Failed to handle active session: \(error)")
        }
    }

    @MainActor
    private func handleActiveSessionEnd(endedId: UUID? = nil) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
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
            Self.logger.info("Ended all active sessions from iPhone")
            lastActiveSessionEndDate = Date()

            if let endedId {
                endedActiveSessionIDs[endedId] = Date()
            }
        } catch {
            Self.logger.error("Failed to end active sessions: \(error)")
        }
    }

    /// Handles consolidated session completion from iPhone (ATOMIC - replaces separate handling)
    @MainActor
    private func handleSessionCompletion(_ completion: SessionCompletionTransfer) async {
        guard let modelContext = modelContext else {
            Self.logger.warning("ModelContext not configured")
            return
        }

        Self.logger.info("🎯 Processing atomic session completion from iPhone")

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
                Self.logger.info("✅ Deleted active session: \(completion.activeSessionId)")
            }
        } catch {
            Self.logger.error("Failed to delete active session: \(error)")
        }

        // 2. Process completed session (same as handleSessionFromPhone)
        await handleSessionFromPhone(completion.completedSession)

        Self.logger.info("✅ Atomic session completion from iPhone handled successfully")
    }
}

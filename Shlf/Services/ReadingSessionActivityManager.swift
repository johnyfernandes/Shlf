//
//  ReadingSessionActivityManager.swift
//  Shlf
//
//  Created by João Fernandes on 27/11/2025.
//

import Foundation
import OSLog
import SwiftData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif

#if canImport(ActivityKit)
import ActivityKit

@MainActor
class ReadingSessionActivityManager {
    static let shared = ReadingSessionActivityManager()
    private static let logger = Logger(subsystem: "com.shlf.app", category: "LiveActivity")

    private(set) var currentActivity: Activity<ReadingSessionWidgetAttributes>?

    private var startTime: Date?
    private var startPage: Int = 0
    private var pausedAt: Date?
    private var totalPausedDuration: TimeInterval = 0
    private var contentUpdateTask: Task<Void, Never>?

    private init() {}

    // MARK: - Start Activity

    func startActivity(book: Book, currentPage: Int? = nil, startPage: Int? = nil, startTime: Date? = nil, themeColorHex: String = "#00CED1") async {
        // End any existing activity first
        await endActivity()

        let activityStartTime = startTime ?? Date()
        let startPageValue = startPage ?? book.currentPage
        let currentPageValue = currentPage ?? startPageValue
        let pagesRead = currentPageValue - startPageValue

        // Calculate LIVE XP based on actual elapsed time
        let actualDuration = startTime != nil ? max(1, Int(Date().timeIntervalSince(startTime!) / 60)) : 0
        let xpEarned = estimatedXP(
            pagesRead: pagesRead,
            durationMinutes: actualDuration
        )

        let coverResources = await resolveCoverResources(book: book, fallbackHex: themeColorHex)
        let compactCoverURLString = await resolveCompactCoverURLString(for: book)
        let attributes = ReadingSessionWidgetAttributes(
            bookTitle: book.title,
            bookAuthor: book.author,
            totalPages: max(1, book.totalPages ?? 1),  // Never 0 to prevent divide by zero
            startPage: startPageValue,
            startTime: activityStartTime,
            themeColorHex: coverResources.themeHex,
            coverImageURLString: coverResources.coverURLString,
            compactCoverURLString: compactCoverURLString
        )

        let initialState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPageValue,
            pagesRead: pagesRead,
            xpEarned: xpEarned,
            isPaused: false,
            timerStartTime: activityStartTime,
            pausedElapsedSeconds: nil
        )

        let activityContent = ActivityContent(state: initialState, staleDate: nil)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )

            currentActivity = activity
            self.startTime = activityStartTime
            self.startPage = startPageValue
            self.pausedAt = nil
            self.totalPausedDuration = 0

            Self.logger.info("✅ Live Activity started: \(activity.id)")
        } catch {
            Self.logger.error("❌ Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update Activity

    func updateActivity(currentPage: Int, xpEarned: Int) async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.debug("⚠️ No Live Activity to update (currentActivity is nil)")
            return
        }

        let pagesRead = currentPage - startPage
        let durationMinutes = elapsedMinutes()
        let xpValue = xpEarned == 0 ? estimatedXP(pagesRead: pagesRead, durationMinutes: durationMinutes) : xpEarned

        let timerStartTime = effectiveTimerStartTime() ?? Date()
        let isCurrentlyPaused = pausedAt != nil
        let pausedElapsedSeconds = isCurrentlyPaused ? Int(elapsedSeconds()) : nil

        let newState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPage,
            pagesRead: pagesRead,
            xpEarned: xpValue,
            isPaused: isCurrentlyPaused,
            timerStartTime: timerStartTime,
            pausedElapsedSeconds: pausedElapsedSeconds
        )

        let updatedContent = ActivityContent(state: newState, staleDate: nil)

        await activity.update(updatedContent)

        Self.logger.info("📊 Live Activity updated: Page \(currentPage), XP \(xpEarned)")
    }

    func updateCurrentPage(_ currentPage: Int) async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.debug("⚠️ No Live Activity to update (currentActivity is nil)")
            return
        }

        let pagesRead = currentPage - startPage
        let xpEarned = estimatedXP(
            pagesRead: pagesRead,
            durationMinutes: elapsedMinutes()
        )

        let timerStartTime = effectiveTimerStartTime() ?? Date()
        let isCurrentlyPaused = pausedAt != nil
        let pausedElapsedSeconds = isCurrentlyPaused ? Int(elapsedSeconds()) : nil

        let newState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPage,
            pagesRead: pagesRead,
            xpEarned: xpEarned,
            isPaused: isCurrentlyPaused,
            timerStartTime: timerStartTime,
            pausedElapsedSeconds: pausedElapsedSeconds
        )

        let updatedContent = ActivityContent(state: newState, staleDate: nil)

        await activity.update(updatedContent)

        Self.logger.info("📊 Live Activity updated from Watch: Page \(currentPage)")
    }

    // MARK: - Pause/Resume Activity

    func pauseActivity() async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.warning("⚠️ No Live Activity to pause (currentActivity is nil)")
            return
        }

        if pausedAt == nil {
            pausedAt = Date()
        }

        let timerStartTime = effectiveTimerStartTime() ?? Date()
        let pausedElapsedSeconds = Int(elapsedSeconds())

        var newState = activity.content.state
        newState.isPaused = true
        newState.timerStartTime = timerStartTime
        newState.pausedElapsedSeconds = pausedElapsedSeconds

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        Self.logger.info("⏸️ Live Activity paused")
    }

    func resumeActivity() async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.warning("⚠️ No Live Activity to resume (currentActivity is nil)")
            return
        }

        if let pausedAt {
            totalPausedDuration += Date().timeIntervalSince(pausedAt)
            self.pausedAt = nil
        }

        let timerStartTime = effectiveTimerStartTime() ?? Date()

        var newState = activity.content.state
        newState.isPaused = false
        newState.timerStartTime = timerStartTime
        newState.pausedElapsedSeconds = nil

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        Self.logger.info("▶️ Live Activity resumed")
    }

    /// Syncs Live Activity timing with an external session source (iPhone/Watch).
    /// Uses the provided timing data as the single source of truth.
    func syncActivityState(
        startTime: Date,
        startPage: Int,
        currentPage: Int,
        totalPausedDuration: TimeInterval,
        pausedAt: Date?,
        isPaused: Bool,
        xpEarned: Int
    ) async {
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.debug("⚠️ No Live Activity to sync (currentActivity is nil)")
            return
        }

        self.startTime = startTime
        self.startPage = startPage
        self.totalPausedDuration = max(0, totalPausedDuration)
        self.pausedAt = isPaused ? (pausedAt ?? Date()) : nil

        let pagesRead = currentPage - startPage
        let durationMinutes = max(0, Int(elapsedSeconds() / 60))
        let xpValue = xpEarned == 0 ? estimatedXP(pagesRead: pagesRead, durationMinutes: durationMinutes) : xpEarned
        let timerStartTime = startTime.addingTimeInterval(self.totalPausedDuration)
        let pausedElapsedSeconds = isPaused ? Int(elapsedSeconds()) : nil

        let newState = ReadingSessionWidgetAttributes.ContentState(
            currentPage: currentPage,
            pagesRead: pagesRead,
            xpEarned: xpValue,
            isPaused: isPaused,
            timerStartTime: timerStartTime,
            pausedElapsedSeconds: pausedElapsedSeconds
        )

        let updatedContent = ActivityContent(state: newState, staleDate: nil)
        await activity.update(updatedContent)

        Self.logger.info("🔄 Live Activity synced to session state")
    }

    // MARK: - Observe Activity Updates

    func observeActivityUpdates(modelContext: ModelContext) async {
        if currentActivity == nil {
            await rehydrateExistingActivity()
        }

        guard let activity = currentActivity else {
            Self.logger.debug("⚠️ No Live Activity to observe (currentActivity is nil)")
            return
        }

        contentUpdateTask?.cancel()
        contentUpdateTask = Task { [weak self] in
            for await update in activity.contentUpdates {
                guard let self else { return }
                await self.applyLiveActivityState(update.state, modelContext: modelContext)
            }
        }
    }

    private func applyLiveActivityState(
        _ state: ReadingSessionWidgetAttributes.ContentState,
        modelContext: ModelContext
    ) async {
        let descriptor = FetchDescriptor<ActiveReadingSession>()
        guard let session = try? modelContext.fetch(descriptor).first else {
            Self.logger.debug("⚠️ No active session to sync from Live Activity")
            return
        }

        var didChange = false

        if session.currentPage != state.currentPage {
            session.currentPage = state.currentPage
            session.book?.currentPage = state.currentPage
            didChange = true
        }

        if session.isPaused != state.isPaused {
            if state.isPaused {
                if session.pausedAt == nil {
                    session.pausedAt = Date()
                }
            } else if let pausedAt = session.pausedAt {
                session.totalPausedDuration += Date().timeIntervalSince(pausedAt)
                session.pausedAt = nil
            }
            session.isPaused = state.isPaused
            didChange = true
        }

        if didChange {
            session.lastUpdated = Date()
            try? modelContext.save()
            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
            NotificationCenter.default.post(name: Notification.Name("watchStatsUpdated"), object: nil)
            Self.logger.info("🔄 Synced Live Activity state into app session")
        }
    }

    // MARK: - End Activity

    func endActivity() async {
        // Rehydrate first to ensure we have a handle to any existing Live Activity
        if currentActivity == nil {
            await rehydrateExistingActivity()
            Self.logger.info("🔄 Rehydrated Live Activity before ending")
        }

        guard let activity = currentActivity else {
            Self.logger.warning("⚠️ No Live Activity to end (currentActivity is nil)")
            return
        }

        let finalState = activity.content.state
        let finalContent = ActivityContent(state: finalState, staleDate: nil)

        await activity.end(finalContent, dismissalPolicy: .immediate)

        currentActivity = nil
        startTime = nil
        startPage = 0
        pausedAt = nil
        totalPausedDuration = 0
        contentUpdateTask?.cancel()
        contentUpdateTask = nil

        Self.logger.info("🛑 Live Activity ended")
    }

    var isActive: Bool {
        currentActivity != nil
    }

    /// Rehydrates the in-memory activity handle and cached metadata after app relaunch.
    /// Picks the most recent ReadingSessionWidget activity if multiple exist.
    func rehydrateExistingActivity() async {
        let active = Activity<ReadingSessionWidgetAttributes>.activities
            .sorted { $0.attributes.startTime > $1.attributes.startTime }
            .first

        guard let active else {
            return
        }

        currentActivity = active
        startPage = active.attributes.startPage
        startTime = active.attributes.startTime
        totalPausedDuration = max(0, active.content.state.timerStartTime.timeIntervalSince(active.attributes.startTime))
        if active.content.state.isPaused {
            let pausedElapsed = TimeInterval(active.content.state.pausedElapsedSeconds ?? 0)
            pausedAt = active.attributes.startTime
                .addingTimeInterval(totalPausedDuration)
                .addingTimeInterval(pausedElapsed)
        } else {
            pausedAt = nil
        }
        Self.logger.info("🔄 Rehydrated existing Live Activity: \(active.id)")
    }

    // MARK: - Get Current State

    func getCurrentPage() -> Int? {
        return currentActivity?.content.state.currentPage
    }

    func getCurrentXP() -> Int? {
        return currentActivity?.content.state.xpEarned
    }

    // MARK: - Helpers

    private func elapsedMinutes() -> Int {
        let seconds = elapsedSeconds()
        return max(0, Int(seconds / 60))
    }

    private func elapsedSeconds(at date: Date = Date()) -> TimeInterval {
        guard let startTime else { return 0 }
        let totalElapsed = date.timeIntervalSince(startTime)
        var pausedTime = totalPausedDuration

        if let pausedAt, date >= pausedAt {
            pausedTime += date.timeIntervalSince(pausedAt)
        }

        return max(0, totalElapsed - pausedTime)
    }

    private func effectiveTimerStartTime() -> Date? {
        guard let startTime else { return nil }
        return startTime.addingTimeInterval(totalPausedDuration)
    }

    /// Calculate LIVE XP for active reading session
    /// Uses actual elapsed time for accuracy
    /// Delegates to centralized XPCalculator for consistency
    /// NOTE: This is the actual XP that will be awarded when session ends
    private func estimatedXP(pagesRead: Int, durationMinutes: Int) -> Int {
        return XPCalculator.calculate(pagesRead: pagesRead, durationMinutes: durationMinutes)
    }
}

// MARK: - Cover Color Sampling

private func resolveCoverResources(book: Book, fallbackHex: String) async -> (themeHex: String, coverURLString: String?) {
#if canImport(UIKit)
    guard let coverURL = book.coverImageURL else {
        return (fallbackHex, nil)
    }

    let localURL = liveActivityCoverFileURL(for: book.id)
    if let localURL, FileManager.default.fileExists(atPath: localURL.path) {
        if let image = UIImage(contentsOfFile: localURL.path),
           let color = image.averageColor,
           let hex = color.toHex() {
            return (hex, localURL.absoluteString)
        }
        return (fallbackHex, localURL.absoluteString)
    }

    do {
        let (data, _) = try await URLSession.shared.data(from: coverURL)
        if let localURL {
            try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: localURL, options: [.atomic])
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.none],
                ofItemAtPath: localURL.path
            )
        }
        if let image = UIImage(data: data),
           let color = image.averageColor,
           let hex = color.toHex() {
            return (hex, localURL?.absoluteString ?? coverURL.absoluteString)
        }
        return (fallbackHex, localURL?.absoluteString ?? coverURL.absoluteString)
    } catch {
        return (fallbackHex, coverURL.absoluteString)
    }
#else
    return (fallbackHex, book.coverImageURL?.absoluteString)
#endif
}

private func liveActivityCoverFileURL(for bookId: UUID) -> URL? {
#if canImport(UIKit)
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SwiftDataConfig.appGroupID) else {
        return nil
    }
    let folder = containerURL.appendingPathComponent("LiveActivityCovers", isDirectory: true)
    return folder.appendingPathComponent("\(bookId.uuidString).jpg")
#else
    return nil
#endif
}

private func liveActivityCompactCoverFileURL(for bookId: UUID) -> URL? {
#if canImport(UIKit)
    guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SwiftDataConfig.appGroupID) else {
        return nil
    }
    let folder = containerURL.appendingPathComponent("LiveActivityCovers", isDirectory: true)
    return folder.appendingPathComponent("\(bookId.uuidString)_compact.jpg")
#else
    return nil
#endif
}

private func resolveCompactCoverURLString(for book: Book) async -> String? {
#if canImport(UIKit)
    guard let coverURL = book.coverImageURL else { return nil }
    guard let compactURL = liveActivityCompactCoverFileURL(for: book.id) else { return nil }

    if FileManager.default.fileExists(atPath: compactURL.path) {
        return compactURL.absoluteString
    }

    do {
        let (data, _) = try await URLSession.shared.data(from: coverURL)
        guard let image = UIImage(data: data) else { return nil }

        let targetSize = CGSize(width: 12, height: 18)
        let scale = max(targetSize.width / image.size.width, targetSize.height / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - scaledSize.width) * 0.5,
            y: (targetSize.height - scaledSize.height) * 0.5
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }

        guard let thumbData = thumbnail.jpegData(compressionQuality: 0.75) else { return nil }

        try? FileManager.default.createDirectory(at: compactURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? thumbData.write(to: compactURL, options: [.atomic])
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.none],
            ofItemAtPath: compactURL.path
        )
        return compactURL.absoluteString
    } catch {
        return nil
    }
#else
    return nil
#endif
}

#if canImport(UIKit)
private extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extent = inputImage.extent
        let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: inputImage,
                kCIInputExtentKey: CIVector(cgRect: extent)
            ]
        )
        guard let outputImage = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        let red = CGFloat(bitmap[0]) / 255.0
        let green = CGFloat(bitmap[1]) / 255.0
        let blue = CGFloat(bitmap[2]) / 255.0
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}

private extension UIColor {
    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
    }
}
#endif
#else

@MainActor
class ReadingSessionActivityManager {
    static let shared = ReadingSessionActivityManager()
    func startActivity(book: Book, currentPage: Int? = nil, startPage: Int? = nil, startTime: Date? = nil, themeColorHex: String = "#00CED1") async {}
    func updateActivity(currentPage: Int, xpEarned: Int) async {}
    func updateCurrentPage(_ currentPage: Int) async {}
    func syncActivityState(
        startTime: Date,
        startPage: Int,
        currentPage: Int,
        totalPausedDuration: TimeInterval,
        pausedAt: Date?,
        isPaused: Bool,
        xpEarned: Int
    ) async {}
    func pauseActivity() async {}
    func resumeActivity() async {}
    func endActivity() async {}
    var isActive: Bool { false }
    func getCurrentPage() -> Int? { nil }
    func getCurrentXP() -> Int? { nil }
    func rehydrateExistingActivity() async {}
}
#endif

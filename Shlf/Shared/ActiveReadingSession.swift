//
//  ActiveReadingSession.swift
//  Shlf
//
//  Shared active reading session across iPhone and Watch
//

import Foundation
import SwiftData

@Model
final class ActiveReadingSession {
    var id: UUID
    var book: Book?
    var startDate: Date
    var currentPage: Int
    var startPage: Int
    var isPaused: Bool
    var pausedAt: Date?
    var totalPausedDuration: TimeInterval
    var lastUpdated: Date
    var sourceDevice: String // "iPhone" or "Watch"

    init(
        id: UUID = UUID(),
        book: Book,
        startDate: Date = Date(),
        currentPage: Int,
        startPage: Int,
        isPaused: Bool = false,
        pausedAt: Date? = nil,
        totalPausedDuration: TimeInterval = 0,
        lastUpdated: Date = Date(),
        sourceDevice: String
    ) {
        self.id = id
        self.book = book
        self.startDate = startDate
        self.currentPage = currentPage
        self.startPage = startPage
        self.isPaused = isPaused
        self.pausedAt = pausedAt
        self.totalPausedDuration = totalPausedDuration
        self.lastUpdated = lastUpdated
        self.sourceDevice = sourceDevice
    }

    // Computed properties
    var elapsedTime: TimeInterval {
        elapsedTime(at: Date())
    }

    func elapsedTime(at date: Date = Date()) -> TimeInterval {
        // If startDate is in future (clock skew), return 0
        // Session hasn't actually started yet
        guard date >= startDate else {
            return 0
        }

        let totalElapsed = date.timeIntervalSince(startDate)

        // Subtract total paused duration
        var pausedTime = totalPausedDuration

        // Add current pause if paused now
        if isPaused, let pausedAt = pausedAt {
            // Only add if pausedAt is valid (not in future)
            if date >= pausedAt {
                pausedTime += date.timeIntervalSince(pausedAt)
            }
        }

        return max(0, totalElapsed - pausedTime)
    }

    var pagesRead: Int {
        // Allow negative values for consistency with ReadingSession
        // (when user goes backwards in book during active session)
        currentPage - startPage
    }

    var durationMinutes: Int {
        let seconds = elapsedTime
        let minutes = seconds / 60

        // Prevent integer overflow: cap at 7 days (10,080 minutes)
        // If session ran longer, something is wrong anyway
        let maxMinutes = 7 * 24 * 60 // 10,080 minutes
        let clampedMinutes = min(minutes, Double(maxMinutes))

        return max(1, Int(clampedMinutes))
    }

    // Check if session should auto-end based on inactivity
    func shouldAutoEnd(inactivityHours: Int) -> Bool {
        let inactivityThreshold = TimeInterval(inactivityHours * 3600)
        return Date().timeIntervalSince(lastUpdated) > inactivityThreshold
    }

    /// Update the lastUpdated timestamp to current time
    /// Call this whenever the session is meaningfully modified
    func touch() {
        lastUpdated = Date()
    }

    /// Validate pause/resume state transitions
    func validatePauseState() -> Bool {
        if isPaused {
            // If paused, must have pausedAt timestamp
            guard pausedAt != nil else { return false }
            // pausedAt should not be in future
            guard let pausedAt = pausedAt, pausedAt <= Date() else { return false }
        }
        return true
    }
}

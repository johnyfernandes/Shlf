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
        let totalElapsed = date.timeIntervalSince(startDate)

        // Subtract total paused duration
        var pausedTime = totalPausedDuration

        // Add current pause if paused now
        if isPaused, let pausedAt = pausedAt {
            pausedTime += date.timeIntervalSince(pausedAt)
        }

        return max(0, totalElapsed - pausedTime)
    }

    var pagesRead: Int {
        max(0, currentPage - startPage)
    }

    var durationMinutes: Int {
        max(1, Int(elapsedTime / 60))
    }

    // Check if session should auto-end based on inactivity
    func shouldAutoEnd(inactivityHours: Int) -> Bool {
        let inactivityThreshold = TimeInterval(inactivityHours * 3600)
        return Date().timeIntervalSince(lastUpdated) > inactivityThreshold
    }
}

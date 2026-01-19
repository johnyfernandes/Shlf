//
//  BookStatsSummary.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation

struct BookStatsSummary {
    let sessions: [ReadingSession]
    let totalPagesRead: Int
    let totalMinutesRead: Int
    let sessionCount: Int
    let averagePagesPerSession: Double
    let averagePagesPerHour: Double
    let longestSession: ReadingSession?
    let longestSessionMinutes: Int
    let longestSessionPages: Int
    let streakDays: Int
    let daysSinceLastRead: Int?
    let firstReadDate: Date?
    let lastReadDate: Date?
    let percentRead: Int?

    static func build(book: Book, sessions: [ReadingSession]) -> BookStatsSummary {
        let pages = sessions.reduce(0) { $0 + max(0, $1.pagesRead) }
        let minutes = sessions.reduce(0) { $0 + max(0, $1.durationMinutes) }
        let count = sessions.count
        let avgPages = count > 0 ? Double(pages) / Double(count) : 0
        let avgSpeed = minutes > 0 ? (Double(pages) / (Double(minutes) / 60.0)) : 0

        let longestByMinutes = sessions.max { $0.durationMinutes < $1.durationMinutes }
        let useMinutes = (longestByMinutes?.durationMinutes ?? 0) > 0
        let longestByPages = sessions.max { max(0, $0.pagesRead) < max(0, $1.pagesRead) }
        let longestSession = useMinutes ? longestByMinutes : longestByPages
        let longestMinutes = useMinutes ? (longestByMinutes?.durationMinutes ?? 0) : 0
        let longestPages = useMinutes ? 0 : max(0, longestByPages?.pagesRead ?? 0)

        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.startDate) })
        let sortedDays = uniqueDays.sorted()

        var streak = 0
        if let lastDay = sortedDays.last {
            streak = 1
            var current = lastDay
            for day in sortedDays.dropLast().reversed() {
                guard let expected = calendar.date(byAdding: .day, value: -1, to: current) else { break }
                if calendar.isDate(day, inSameDayAs: expected) {
                    streak += 1
                    current = day
                } else {
                    break
                }
            }
        }

        let firstRead = sessions.map(\.startDate).min()
        let lastRead = sessions.map(\.startDate).max()
        let daysSince: Int?
        if let lastRead {
            let start = calendar.startOfDay(for: lastRead)
            let today = calendar.startOfDay(for: Date())
            daysSince = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        } else {
            daysSince = nil
        }

        let percent: Int?
        if let totalPages = book.totalPages, totalPages > 0 {
            percent = min(100, Int((Double(pages) / Double(totalPages) * 100).rounded()))
        } else {
            percent = nil
        }

        return BookStatsSummary(
            sessions: sessions,
            totalPagesRead: pages,
            totalMinutesRead: minutes,
            sessionCount: count,
            averagePagesPerSession: avgPages,
            averagePagesPerHour: avgSpeed,
            longestSession: longestSession,
            longestSessionMinutes: longestMinutes,
            longestSessionPages: longestPages,
            streakDays: streak,
            daysSinceLastRead: daysSince,
            firstReadDate: firstRead,
            lastReadDate: lastRead,
            percentRead: percent
        )
    }
}

//
//  XPCalculator.swift
//  Shlf
//
//  Centralized XP calculation - single source of truth
//

import Foundation

/// Centralized XP calculation engine
/// IMPORTANT: This is the ONLY place XP calculation should be defined
/// All other code should call these methods to ensure consistency
struct XPCalculator {

    /// Calculate XP for a reading session
    /// - Parameters:
    ///   - pagesRead: Number of pages read in the session
    ///   - durationMinutes: Total duration of the session in minutes
    /// - Returns: Total XP earned (base + duration bonus)
    static func calculate(pagesRead: Int, durationMinutes: Int) -> Int {
        let baseXP = max(0, pagesRead) * 10
        let durationBonus = calculateDurationBonus(durationMinutes: durationMinutes)
        return baseXP + durationBonus
    }

    /// Calculate XP from a ReadingSession model
    /// - Parameter session: The reading session
    /// - Returns: Total XP earned
    static func calculate(for session: ReadingSession) -> Int {
        let pagesRead = session.pagesRead
        let durationMinutes = session.durationMinutes
        return calculate(pagesRead: pagesRead, durationMinutes: durationMinutes)
    }

    /// Calculate duration bonus based on session length
    /// - Parameter durationMinutes: Total duration in minutes
    /// - Returns: Bonus XP for long reading sessions
    private static func calculateDurationBonus(durationMinutes: Int) -> Int {
        if durationMinutes >= 180 {
            return 200  // 3+ hours
        } else if durationMinutes >= 120 {
            return 100  // 2+ hours
        } else if durationMinutes >= 60 {
            return 50   // 1+ hour
        } else {
            return 0    // Less than 1 hour
        }
    }

    // MARK: - Configuration Constants

    /// Base XP per page read
    static let xpPerPage = 10

    /// Duration thresholds and bonuses
    static let durationBonuses: [(minMinutes: Int, bonus: Int)] = [
        (180, 200),  // 3+ hours
        (120, 100),  // 2+ hours
        (60, 50)     // 1+ hour
    ]
}

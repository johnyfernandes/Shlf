//
//  StreakService.swift
//  Shlf
//
//  Streak protection helpers.
//

import Foundation
import SwiftData

@MainActor
struct StreakService {
    let modelContext: ModelContext
    private let calendar: Calendar

    private let pardonWindowHours = 48
    private let pardonCooldownDays = 7

    init(modelContext: ModelContext, calendar: Calendar = .current) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    func streakDeadline(for profile: UserProfile, now: Date = Date()) -> Date? {
        guard let lastDay = profile.lastReadingDate else { return nil }
        let lastStart = calendar.startOfDay(for: lastDay)
        let todayStart = calendar.startOfDay(for: now)
        let daysSince = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0
        guard daysSince <= 1 else { return nil }
        return calendar.date(byAdding: .day, value: 1, to: todayStart)
    }

    func pardonEligibility(for profile: UserProfile, now: Date = Date()) -> StreakPardonEligibility {
        guard let lastDay = profile.lastReadingDate else { return .notNeeded }
        let lastStart = calendar.startOfDay(for: lastDay)
        let todayStart = calendar.startOfDay(for: now)
        let daysSince = calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0

        guard daysSince >= 2 else { return .notNeeded }

        let missedDay = calendar.date(byAdding: .day, value: 1, to: lastStart) ?? lastStart

        guard daysSince == 2 else {
            return .expired(missedDay: missedDay)
        }

        let deadline = calendar.date(byAdding: .hour, value: pardonWindowHours, to: missedDay) ?? missedDay
        guard now <= deadline else {
            return .expired(missedDay: missedDay)
        }

        if let lastPardonDate = profile.lastPardonDate {
            let cooldownEnd = calendar.date(byAdding: .day, value: pardonCooldownDays, to: lastPardonDate) ?? lastPardonDate
            if now < cooldownEnd {
                return .cooldown(nextAvailable: cooldownEnd)
            }
        }

        return .available(missedDay: missedDay, deadline: deadline)
    }

    func applyPardon(for profile: UserProfile, now: Date = Date()) throws -> StreakPardonEligibility {
        let eligibility = pardonEligibility(for: profile, now: now)
        guard case let .available(missedDay, _) = eligibility else {
            return eligibility
        }

        let missedStart = calendar.startOfDay(for: missedDay)
        removeLossEvent(for: missedStart)

        let event = StreakEvent(
            date: missedStart,
            type: .saved,
            streakLength: profile.currentStreak
        )
        modelContext.insert(event)
        profile.lastPardonDate = now

        let engine = GamificationEngine(modelContext: modelContext)
        engine.refreshStreak(for: profile)
        try? modelContext.save()

        return eligibility
    }

    private func removeLossEvent(for day: Date) {
        let descriptor = FetchDescriptor<StreakEvent>()
        guard let events = try? modelContext.fetch(descriptor) else { return }
        for event in events where event.type == .lost && calendar.startOfDay(for: event.date) == day {
            modelContext.delete(event)
        }
    }
}

enum StreakPardonEligibility: Equatable {
    case notNeeded
    case available(missedDay: Date, deadline: Date)
    case cooldown(nextAvailable: Date)
    case expired(missedDay: Date)
}

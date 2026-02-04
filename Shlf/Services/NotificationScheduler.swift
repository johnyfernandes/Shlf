//
//  NotificationScheduler.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let reminderIdentifier = "streakReminder"

    private init() {}

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func refreshSchedule(for profile: UserProfile) async {
        if !profile.streakReminderEnabled || profile.streaksPaused {
            await cancelReminder()
            return
        }

        await scheduleNextReminder(for: profile)
    }

    func scheduleNextReminder(for profile: UserProfile) async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        guard profile.streakReminderEnabled, !profile.streaksPaused else { return }

        let now = Date()
        let calendar = Calendar.current
        let didReadToday = profile.lastReadingDate.map { calendar.isDate($0, inSameDayAs: now) } ?? false

        guard let fireDate = nextFireDate(
            from: now,
            hour: profile.streakReminderHour,
            minute: profile.streakReminderMinute,
            skipToday: didReadToday
        ) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Notifications.StreakReminder.Title")
        content.body = String(localized: "Notifications.StreakReminder.Body")
        content.sound = .default
        content.interruptionLevel = profile.streakReminderRespectFocus ? .active : .timeSensitive

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            // Intentionally ignore scheduling errors.
        }
    }

    func sendTestNotification() async {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Notifications.StreakReminder.Title")
        content.body = String(localized: "Notifications.StreakReminder.Body")
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: "streakReminder.test", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            // Ignore errors in dev trigger.
        }
    }

    func cancelReminder() async {
        let center = UNUserNotificationCenter.current()
        await center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    private func nextFireDate(from now: Date, hour: Int, minute: Int, skipToday: Bool) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute

        if let today = calendar.date(from: components) {
            if !skipToday && today > now {
                return today
            }
        }

        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
        var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        tomorrowComponents.hour = hour
        tomorrowComponents.minute = minute
        return calendar.date(from: tomorrowComponents)
    }
}

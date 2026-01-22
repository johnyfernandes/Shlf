//
//  Notifications.swift
//  Shlf
//
//  Created by Codex on 22/01/2026.
//

import Foundation

extension Notification.Name {
    static let watchReachabilityDidChange = Notification.Name("watchReachabilityDidChange")
    static let watchSessionReceived = Notification.Name("watchSessionReceived")
    static let watchStatsUpdated = Notification.Name("watchStatsUpdated")
    static let readingSessionLogged = Notification.Name("readingSessionLogged")
    static let achievementUnlocked = Notification.Name("achievementUnlocked")
}

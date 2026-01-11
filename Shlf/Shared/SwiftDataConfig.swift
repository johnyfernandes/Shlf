//
//  SwiftDataConfig.swift
//  Shlf
//
//  Shared SwiftData configuration for app, widget, and Live Activity
//

import Foundation
import SwiftData

@MainActor
enum SwiftDataConfig {
    static let appGroupID = "group.joaofernandes.Shlf"
    private static let cloudContainerId = "iCloud.joaofernandes.Shlf"
    private static let storageModeKey = "storageMode"

    enum StorageMode: String {
        case local
        case cloud
    }

    static func createModelContainer(storageMode: StorageMode? = nil) throws -> ModelContainer {
        let schema = Schema([
            Book.self,
            ReadingSession.self,
            UserProfile.self,
            ReadingGoal.self,
            Achievement.self,
            ActiveReadingSession.self,
            BookPosition.self,
            Quote.self,
            StreakEvent.self
        ])

        let mode = storageMode ?? currentStorageMode()
        let fileName = mode == .cloud ? "ShlfCloud.sqlite" : "Shlf.sqlite"
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: containerURL(fileName: fileName),
            cloudKitDatabase: mode == .cloud ? .private(cloudContainerId) : .none
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    static func currentStorageMode() -> StorageMode {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        if let raw = defaults.string(forKey: storageModeKey),
           let mode = StorageMode(rawValue: raw) {
            return mode
        }
        defaults.set(StorageMode.local.rawValue, forKey: storageModeKey)
        return .local
    }

    static func setStorageMode(_ mode: StorageMode) {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        defaults.set(mode.rawValue, forKey: storageModeKey)
    }

    private static func containerURL(fileName: String) -> URL {
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("App group container not found: \(appGroupID)")
        }

        return appGroupURL.appendingPathComponent(fileName)
    }
}

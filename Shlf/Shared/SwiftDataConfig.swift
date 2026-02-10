//
//  SwiftDataConfig.swift
//  Shlf
//
//  Shared SwiftData configuration for app, widget, and Live Activity
//

import Foundation
import SwiftData
import OSLog

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
            url: try containerURL(fileName: fileName),
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

    enum AppGroupError: LocalizedError {
        case missingAppGroupContainer(String)

        var errorDescription: String? {
            switch self {
            case .missingAppGroupContainer(let id):
                return "App group container not found: \(id)"
            }
        }
    }

    private static func containerURL(fileName: String) throws -> URL {
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.shlf.app", category: "SwiftData")
                .error("App group container not found: \(appGroupID)")
            throw AppGroupError.missingAppGroupContainer(appGroupID)
        }

        return appGroupURL.appendingPathComponent(fileName)
    }
}

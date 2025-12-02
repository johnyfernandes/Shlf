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

    static func createModelContainer() throws -> ModelContainer {
        let schema = Schema([
            Book.self,
            ReadingSession.self,
            UserProfile.self,
            ReadingGoal.self,
            Achievement.self
        ])

        // Use app group container for sharing between app and extensions
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: containerURL(),
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    private static func containerURL() -> URL {
        guard let appGroupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else {
            fatalError("App group container not found: \(appGroupID)")
        }

        return appGroupURL.appendingPathComponent("Shlf.sqlite")
    }
}

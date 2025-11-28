//
//  ShlfWatchApp.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 27/11/2025.
//

import SwiftUI
import SwiftData

@main
struct ShlfWatch_Watch_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            ReadingSession.self,
            UserProfile.self,
            ReadingGoal.self,
            Achievement.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    WatchConnectivityManager.shared.configure(modelContext: sharedModelContainer.mainContext)
                    WatchConnectivityManager.shared.activate()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

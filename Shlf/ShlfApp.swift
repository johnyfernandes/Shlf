//
//  ShlfApp.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

@main
struct ShlfApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            ReadingSession.self,
            UserProfile.self,
            ReadingGoal.self,
            Achievement.self
        ])

        // Local storage only - sync via WatchConnectivity
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

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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Book.self,
            ReadingSession.self,
            UserProfile.self,
            ReadingGoal.self,
            Achievement.self
        ])
    }
}

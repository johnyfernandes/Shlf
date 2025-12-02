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
    @State private var modelContainer: ModelContainer?
    @State private var modelError: Error?

    init() {
        do {
            // Include ActiveReadingSession so the Watch can persist and sync live sessions
            let schema = Schema([
                Book.self,
                ReadingSession.self,
                UserProfile.self,
                ReadingGoal.self,
                Achievement.self,
                ActiveReadingSession.self
            ])
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            _modelContainer = State(initialValue: container)
        } catch {
            _modelError = State(initialValue: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let error = modelError {
                ErrorStateView(error: error)
            } else if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
                    .onAppear {
                        WatchConnectivityManager.shared.configure(modelContext: container.mainContext)
                        WatchConnectivityManager.shared.activate()
                    }
            } else {
                ProgressView()
            }
        }
    }
}

struct ErrorStateView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Unable to Start")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

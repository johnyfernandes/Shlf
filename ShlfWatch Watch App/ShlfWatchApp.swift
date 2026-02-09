//
//  ShlfWatchApp.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 27/11/2025.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct ShlfWatch_Watch_AppApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var modelError: Error?
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("debugWatchLanguageOverride") private var debugLanguageOverride = WatchAppLanguage.system.rawValue

    init() {
        do {
            // Include ActiveReadingSession so the Watch can persist and sync live sessions
            let schema = Schema([
                Book.self,
                ReadingSession.self,
                UserProfile.self,
                ReadingGoal.self,
                Achievement.self,
                ActiveReadingSession.self,
                StreakEvent.self
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

    private var resolvedLocale: Locale? {
        guard let language = WatchAppLanguage(rawValue: debugLanguageOverride) else {
            return nil
        }
        return language.locale
    }

    var body: some Scene {
        WindowGroup {
            if let error = modelError {
                ErrorStateView(error: error)
            } else if let container = modelContainer {
                ContentView()
                    .modelContainer(container)
                    .environment(\.locale, resolvedLocale ?? Locale.current)
                    .onAppear {
                        WatchConnectivityManager.shared.configure(modelContext: container.mainContext)
                        WatchConnectivityManager.shared.activate()
                    }
            } else {
                ProgressView()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard let container = modelContainer else { return }

            switch newPhase {
            case .background:
                // Watch going to background - persist active session state immediately
                Task { @MainActor in
                    do {
                        try container.mainContext.save()
                        WatchConnectivityManager.logger.info("💾 Saved on background")
                    } catch {
                        WatchConnectivityManager.logger.error("Failed to save on background: \(error)")
                    }
                }

            case .active:
                // Watch returning to foreground - just log, data is already synced
                WatchConnectivityManager.logger.info("⏰ Watch app returned to foreground")

            case .inactive:
                // Transitioning - save just in case
                Task { @MainActor in
                    try? container.mainContext.save()
                }

            @unknown default:
                break
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

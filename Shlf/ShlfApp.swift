//
//  ShlfApp.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct ShlfApp: App {
    @State private var modelContainer: ModelContainer?
    @State private var modelError: Error?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var toastCenter = ToastCenter()
#if DEBUG
    @AppStorage(AppLanguage.overrideKey) private var developerLanguageOverride = AppLanguage.system.rawValue
#endif

    init() {
        UNUserNotificationCenter.current().delegate = AppNotificationDelegate.shared
        do {
            // Use shared configuration for app group access (widget/Live Activity)
            // Note: Schema is defined in SwiftDataConfig
            let container = try SwiftDataConfig.createModelContainer()
            _modelContainer = State(initialValue: container)
        } catch {
            _modelError = State(initialValue: error)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let error = modelError {
                    ErrorStateView(error: error)
                } else if let container = modelContainer {
                    ContentView()
                        .modelContainer(container)
                        .environmentObject(toastCenter)
                        .onAppear {
                            WatchConnectivityManager.shared.configure(modelContext: container.mainContext, container: container)
                            WatchConnectivityManager.shared.activate()
#if DEBUG
                            WatchConnectivityManager.shared.sendLanguageOverrideToWatch(developerLanguageOverride)
#endif
                            WidgetDataExporter.exportSnapshot(modelContext: container.mainContext)
                            Task {
                                await ReadingSessionActivityManager.shared.rehydrateExistingActivity()
                                await ReadingSessionActivityManager.shared.observeActivityUpdates(modelContext: container.mainContext)
                            }

                            Task { @MainActor in
                                await StoreKitService.shared.refreshEntitlements()
                                let descriptor = FetchDescriptor<UserProfile>()
                                if let profiles = try? container.mainContext.fetch(descriptor),
                                   let profile = profiles.first {
                                    let isPro = StoreKitService.shared.isProUser
                                    if profile.isProUser != isPro {
                                        profile.isProUser = isPro
                                        try? container.mainContext.save()
                                    }
                                }
                            }

                            // Cleanup stale active sessions based on user preferences
                            Task { @MainActor in
                                await ActiveSessionCleanup.cleanupStaleSessionsIfNeeded(modelContext: container.mainContext)
                            }

                            // Recalculate stats on launch (fixes any incorrect XP/streak from deletions)
                            Task { @MainActor in
                                let descriptor = FetchDescriptor<UserProfile>()
                                if let profiles = try? container.mainContext.fetch(descriptor),
                                   let profile = profiles.first {
                                    let engine = GamificationEngine(modelContext: container.mainContext)
                                    engine.recalculateStats(for: profile)
                                    try? container.mainContext.save()
                                }
                            }
                        }
                } else {
                    ProgressView()
                }
            }
            .debugLocale(debugLanguage)
#if DEBUG
            .onChange(of: developerLanguageOverride) { _, newValue in
                WatchConnectivityManager.shared.sendLanguageOverrideToWatch(newValue)
            }
#endif
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard let container = modelContainer else { return }

            switch newPhase {
            case .background:
                // App going to background - persist everything immediately
                Task { @MainActor in
                    do {
                        try container.mainContext.save()
                        WidgetDataExporter.exportSnapshot(modelContext: container.mainContext)
                    } catch {
                        print("Failed to save on background: \(error)")
                    }
                }

            case .active:
                // App returning to foreground - rehydrate and cleanup
                Task { @MainActor in
                    await ReadingSessionActivityManager.shared.rehydrateExistingActivity()
                    await ReadingSessionActivityManager.shared.observeActivityUpdates(modelContext: container.mainContext)
                    await ActiveSessionCleanup.cleanupStaleSessionsIfNeeded(modelContext: container.mainContext)
                    WidgetDataExporter.exportSnapshot(modelContext: container.mainContext)
                }

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

    private var debugLanguage: AppLanguage? {
        #if DEBUG
        return AppLanguage(rawValue: developerLanguageOverride)
        #else
        return nil
        #endif
    }
}

struct ErrorStateView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Unable to Start")
                .font(.title)
                .fontWeight(.semibold)

            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Restart App") {
                exit(0)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

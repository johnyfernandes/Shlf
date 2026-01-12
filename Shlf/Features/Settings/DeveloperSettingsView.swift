//
//  DeveloperSettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

#if DEBUG
struct DeveloperSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var storeKit = StoreKitService.shared
    @AppStorage(AppLanguage.overrideKey) private var languageOverride = AppLanguage.system.rawValue
    @State private var showResetAlert = false
    @State private var showGenerateAlert = false
    @State private var showClearMockAlert = false
    @State private var isWorking = false
    @State private var isSeeding = false
    @State private var mockRange: MockSeedRange = .month
    @State private var mockIntensity: MockSeedIntensity = .balanced
    @State private var includePardon = true
    @State private var mockStatus = ""
    @State private var showMockError = false
    @State private var mockErrorMessage = ""
    @State private var mockSummary = MockDataStore.shared.summary

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        Form {
            Section("Localization") {
                Picker("App Language", selection: $languageOverride) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayNameKey).tag(language.rawValue)
                    }
                }
            }

            Section("Purchases") {
                Button("Reload Products") {
                    Task { await storeKit.loadProducts() }
                }

                Button("Refresh Entitlements") {
                    Task { await storeKit.refreshEntitlements() }
                }

                Button("Reset Pro Status (Local)", role: .destructive) {
                    showResetAlert = true
                }
                .disabled(isWorking)
            }

            Section("Status") {
                HStack {
                    Text("StoreKit Pro")
                    Spacer()
                    Text(storeKit.isProUser ? "Yes" : "No")
                        .foregroundStyle(storeKit.isProUser ? Theme.Colors.success : Theme.Colors.secondaryText)
                }

                HStack {
                    Text("Cached Pro")
                    Spacer()
                    Text(ProAccess.cachedIsPro ? "Yes" : "No")
                        .foregroundStyle(ProAccess.cachedIsPro ? Theme.Colors.success : Theme.Colors.secondaryText)
                }

                if let profile = profile {
                    HStack {
                        Text("Profile Pro")
                        Spacer()
                        Text(profile.isProUser ? "Yes" : "No")
                            .foregroundStyle(profile.isProUser ? Theme.Colors.success : Theme.Colors.secondaryText)
                    }
                }
            }

            Section("Mock Data") {
                Picker("Range", selection: $mockRange) {
                    ForEach(MockSeedRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }

                Picker("Density", selection: $mockIntensity) {
                    ForEach(MockSeedIntensity.allCases) { intensity in
                        Text(intensity.rawValue).tag(intensity)
                    }
                }

                Toggle("Include Pardon Day", isOn: $includePardon)

                Button("Generate Mock Data") {
                    showGenerateAlert = true
                }
                .disabled(isSeeding)

                Button("Clear Mock Data", role: .destructive) {
                    showClearMockAlert = true
                }
                .disabled(isSeeding || mockSummary == nil)

                if isSeeding {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(mockStatus.isEmpty ? "Working..." : mockStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let summary = mockSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Seed: \(summary.rangeLabel) · \(summary.intensityLabel)")
                            .font(.caption)
                        Text("Books \(summary.bookCount) · Sessions \(summary.sessionCount) · Achievements \(summary.achievementCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Seeded \(summary.seededAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Generates realistic reading data and downloads real covers.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Pro Status?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetProStatus()
            }
        } message: {
            Text("Clears local Pro flags so you can test fresh purchases.")
        }
        .alert("Generate Mock Data?", isPresented: $showGenerateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Generate", role: .destructive) {
                generateMockData()
            }
        } message: {
            Text("This will wipe your current books, sessions, achievements, and streak history.")
        }
        .alert("Clear Mock Data?", isPresented: $showClearMockAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearMockData()
            }
        } message: {
            Text("Removes only the last generated mock dataset.")
        }
        .alert("Mock Data Error", isPresented: $showMockError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mockErrorMessage)
        }
    }

    private func resetProStatus() {
        isWorking = true
        Task { @MainActor in
            storeKit.resetLocalProState()
            if let profile = profile {
                profile.isProUser = false
                try? modelContext.save()
            }
            isWorking = false
        }
    }

    private func generateMockData() {
        isSeeding = true
        mockStatus = "Starting..."

        Task { @MainActor in
            let generator = MockDataGenerator(modelContext: modelContext)
            do {
                let summary = try await generator.generate(
                    configuration: MockSeedConfiguration(
                        range: mockRange,
                        intensity: mockIntensity,
                        includePardon: includePardon
                    ),
                    onProgress: { status in
                        mockStatus = status
                    }
                )
                mockSummary = summary
                mockStatus = "Done"
            } catch {
                mockErrorMessage = error.localizedDescription
                showMockError = true
            }
            isSeeding = false
        }
    }

    private func clearMockData() {
        isSeeding = true
        mockStatus = "Clearing..."

        let generator = MockDataGenerator(modelContext: modelContext)
        do {
            _ = try generator.clearMockData()
            mockSummary = MockDataStore.shared.summary
            mockStatus = "Done"
        } catch {
            mockErrorMessage = error.localizedDescription
            showMockError = true
        }

        isSeeding = false
    }
}
#endif

#if DEBUG
import SwiftUI
import SwiftData

struct DeveloperSettingsWatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @AppStorage("debugWatchThemeOverrideEnabled") private var debugThemeOverrideEnabled = false
    @AppStorage("debugWatchThemeOverrideColor") private var debugThemeOverrideRawValue = ThemeColor.blue.rawValue
    @AppStorage("debugWatchLanguageOverride") private var debugLanguageOverride = WatchAppLanguage.system.rawValue
    @State private var mockRange: MockSeedRange = .month
    @State private var mockIntensity: MockSeedIntensity = .balanced
    @State private var includePardon = true
    @State private var isSeeding = false
    @State private var statusMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showGenerateAlert = false
    @State private var showClearAlert = false
    @State private var mockSummary = MockDataStore.shared.summary

    var body: some View {
        List {
            themeSection()
            languageSection()
            mockDataSection()
        }
        .navigationTitle("Watch.Developer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Watch.GenerateMockData.Title", isPresented: $showGenerateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Watch.Generate", role: .destructive) {
                generateMockData()
            }
        } message: {
            Text("Watch.GenerateMockData.Message")
        }
        .alert("Watch.ClearMockData.Title", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Watch.Clear", role: .destructive) {
                clearMockData()
            }
        } message: {
            Text("Watch.ClearMockData.Message")
        }
        .alert("Watch.MockDataError", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func themeSection() -> some View {
        Section("Watch.ThemePreview") {
            Toggle("Watch.OverrideTheme", isOn: $debugThemeOverrideEnabled)
                .tint(themeColor.color)

            if debugThemeOverrideEnabled {
                Picker("Watch.ThemeColor", selection: $debugThemeOverrideRawValue) {
                    ForEach(ThemeColor.allCases) { color in
                        Text(color.displayNameKey).tag(color.rawValue)
                    }
                }
            } else {
                Text("Watch.FollowsPhoneTheme")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func languageSection() -> some View {
        Section("Watch.Language") {
            Picker("Watch.Language", selection: $debugLanguageOverride) {
                ForEach(WatchAppLanguage.allCases) { language in
                    Text(language.displayNameKey)
                        .tag(language.rawValue)
                }
            }

            Text("Watch.Language.Help")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func mockDataSection() -> some View {
        Section("Watch.MockData") {
            Picker("Watch.Range", selection: $mockRange) {
                ForEach(MockSeedRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }

            Picker("Watch.Density", selection: $mockIntensity) {
                ForEach(MockSeedIntensity.allCases) { intensity in
                    Text(intensity.rawValue).tag(intensity)
                }
            }

            Toggle("Watch.IncludePardon", isOn: $includePardon)
                .tint(themeColor.color)

            Button("Watch.GenerateMockData") {
                showGenerateAlert = true
            }
            .disabled(isSeeding)

            Button("Watch.ClearMockData", role: .destructive) {
                showClearAlert = true
            }
            .disabled(isSeeding || mockSummary == nil)

            if isSeeding {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView()
                    Text(statusMessage.isEmpty ? String(localized: "Watch.Working") : statusMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let summary = mockSummary {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch.LastSeed")
                        .font(.caption)
                    Text(verbatim: "\(summary.rangeLabel) · \(summary.intensityLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "Books %lld · Sessions %lld"),
                            summary.bookCount,
                            summary.sessionCount
                        )
                    )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func generateMockData() {
        isSeeding = true
        statusMessage = String(localized: "Watch.Starting")

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
                        statusMessage = status
                    }
                )
                mockSummary = summary
                statusMessage = String(localized: "Watch.Done")
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSeeding = false
        }
    }

    private func clearMockData() {
        isSeeding = true
        statusMessage = String(localized: "Watch.Clearing")

        let generator = MockDataGenerator(modelContext: modelContext)
        do {
            _ = try generator.clearMockData()
            mockSummary = MockDataStore.shared.summary
            statusMessage = String(localized: "Watch.Done")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSeeding = false
    }
}
#endif

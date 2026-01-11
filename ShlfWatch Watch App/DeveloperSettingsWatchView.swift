#if DEBUG
import SwiftUI
import SwiftData

struct DeveloperSettingsWatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
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

                Toggle("Include Pardon", isOn: $includePardon)
                    .tint(themeColor.color)

                Button("Generate Mock Data") {
                    showGenerateAlert = true
                }
                .disabled(isSeeding)

                Button("Clear Mock Data", role: .destructive) {
                    showClearAlert = true
                }
                .disabled(isSeeding || mockSummary == nil)

                if isSeeding {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView()
                        Text(statusMessage.isEmpty ? "Working..." : statusMessage)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let summary = mockSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Seed")
                            .font(.caption)
                        Text("\(summary.rangeLabel) · \(summary.intensityLabel)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("Books \(summary.bookCount) · Sessions \(summary.sessionCount)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Developer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Generate Mock Data?", isPresented: $showGenerateAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Generate", role: .destructive) {
                generateMockData()
            }
        } message: {
            Text("This will wipe existing reading data on this Watch.")
        }
        .alert("Clear Mock Data?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearMockData()
            }
        } message: {
            Text("Removes only the last generated mock dataset.")
        }
        .alert("Mock Data Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func generateMockData() {
        isSeeding = true
        statusMessage = "Starting..."

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
                statusMessage = "Done"
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSeeding = false
        }
    }

    private func clearMockData() {
        isSeeding = true
        statusMessage = "Clearing..."

        let generator = MockDataGenerator(modelContext: modelContext)
        do {
            _ = try generator.clearMockData()
            mockSummary = MockDataStore.shared.summary
            statusMessage = "Done"
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSeeding = false
    }
}
#endif

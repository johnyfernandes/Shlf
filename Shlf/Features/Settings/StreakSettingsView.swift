//
//  StreakSettingsView.swift
//  Shlf
//
//  Settings for streak behavior
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI
import SwiftData

struct StreakSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    themeColor.color.opacity(0.12),
                    themeColor.color.opacity(0.04),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Streaks track consecutive reading days to keep momentum. You can pause them anytime without losing your current streak.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "pause.circle.fill")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Pause Streaks")
                                .font(.headline)
                        }

                        Toggle(isOn: Binding(
                            get: { profile.streaksPaused },
                            set: { handlePauseToggle($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Pause streak tracking")
                                    .font(.subheadline.weight(.medium))

                                Text("Streak cards, streak goals, and streak achievements are hidden while paused.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Streaks")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }

    private func handlePauseToggle(_ isPaused: Bool) {
        profile.streaksPaused = isPaused
        if !isPaused, profile.currentStreak > 0 {
            profile.lastReadingDate = Calendar.current.startOfDay(for: Date())
        }
        do {
            try modelContext.save()
            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)
        } catch {
            saveErrorMessage = "Failed to save setting: \(error.localizedDescription)"
            showSaveError = true
        }
    }
}

#Preview {
    NavigationStack {
        StreakSettingsView(profile: UserProfile())
            .modelContainer(for: [UserProfile.self], inMemory: true)
    }
}
#endif

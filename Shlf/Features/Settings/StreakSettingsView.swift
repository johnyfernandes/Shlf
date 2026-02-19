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
    @Environment(\.locale) private var locale
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

                            Text("StreakSettings.AboutTitle")
                                .font(.headline)
                        }

                        Text("StreakSettings.AboutDescription")
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

                            Text("StreakSettings.Pause.Title")
                                .font(.headline)
                        }

                        Toggle(isOn: Binding(
                            get: { profile.streaksPaused },
                            set: { handlePauseToggle($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("StreakSettings.Pause.Toggle")
                                    .font(.subheadline.weight(.medium))

                                Text("StreakSettings.Pause.Detail")
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
        .navigationTitle("StreakSettings.Title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("StreakSettings.SaveErrorTitle", isPresented: $showSaveError) {
            Button("Common.OK") {}
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
            saveErrorMessage = String.localizedStringWithFormat(
                localized("StreakSettings.SaveErrorFormat", locale: locale),
                error.localizedDescription
            )
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

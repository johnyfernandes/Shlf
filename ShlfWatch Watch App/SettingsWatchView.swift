//
//  SettingsWatchView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 28/11/2025.
//

import SwiftUI
import SwiftData

struct SettingsWatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query private var profiles: [UserProfile]
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        List {
            if let profile = profile {
                if profile.showSettingsOnWatch {
                    Section {
                        Toggle(isOn: Binding(
                            get: { profile.hideAutoSessionsWatch },
                            set: { newValue in
                                profile.hideAutoSessionsWatch = newValue
                                do {
                                    try modelContext.save()
                                    // Send to iPhone immediately
                                    WatchConnectivityManager.shared.sendProfileSettingsToPhone(profile)
                                } catch {
                                    saveErrorMessage = String.localizedStringWithFormat(
                                        String(localized: "Watch.SaveErrorDetail"),
                                        error.localizedDescription
                                    )
                                    showSaveError = true
                                    profile.hideAutoSessionsWatch = !newValue // Revert on failure
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Watch.HideQuickSessions")
                                    .font(.caption)
                                Text("Watch.OnlyTimerSessions")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)

                        Toggle(isOn: Binding(
                            get: { profile.useCircularProgressWatch },
                            set: { newValue in
                                profile.useCircularProgressWatch = newValue
                                do {
                                    try modelContext.save()
                                    WatchConnectivityManager.shared.sendProfileSettingsToPhone(profile)
                                } catch {
                                    saveErrorMessage = String.localizedStringWithFormat(
                                        String(localized: "Watch.SaveErrorDetail"),
                                        error.localizedDescription
                                    )
                                    showSaveError = true
                                    profile.useCircularProgressWatch = !newValue // Revert on failure
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Watch.CircularProgress")
                                    .font(.caption)
                                Text("Watch.ShowProgressRing")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)

                        Toggle(isOn: Binding(
                            get: { profile.enableWatchPositionMarking },
                            set: { newValue in
                                profile.enableWatchPositionMarking = newValue
                                do {
                                    try modelContext.save()
                                    WatchConnectivityManager.shared.sendProfileSettingsToPhone(profile)
                                } catch {
                                    saveErrorMessage = String.localizedStringWithFormat(
                                        String(localized: "Watch.SaveErrorDetail"),
                                        error.localizedDescription
                                    )
                                    showSaveError = true
                                    profile.enableWatchPositionMarking = !newValue // Revert on failure
                                }
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Watch.MarkPosition")
                                    .font(.caption)
                                Text("Watch.SavePageLine")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)
                    } header: {
                        Text("Watch.Customization")
                    }

                    Section {
                        Text("Watch.QuickSessionsInfo")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    #if DEBUG
                    Section("Watch.Developer") {
                        NavigationLink("Watch.DeveloperTools") {
                            DeveloperSettingsWatchView()
                        }
                    }
                    #endif
                } else {
                    Section {
                        Text("Watch.SettingsManagedOniPhone")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Watch.Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Watch.SaveError", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsWatchView()
    }
}

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
                                try? modelContext.save()
                                // Send to iPhone immediately
                                WatchConnectivityManager.shared.sendProfileSettingsToPhone(profile)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hide Quick Sessions")
                                    .font(.caption)
                                Text("Only show timer sessions")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)

                        Toggle(isOn: Binding(
                            get: { profile.useCircularProgressWatch },
                            set: { newValue in
                                profile.useCircularProgressWatch = newValue
                                try? modelContext.save()
                                WatchConnectivityManager.shared.sendProfileSettingsToPhone(profile)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Circular Progress")
                                    .font(.caption)
                                Text("Show progress as a ring")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)

                        Toggle(isOn: Binding(
                            get: { profile.enableWatchPositionMarking },
                            set: { newValue in
                                profile.enableWatchPositionMarking = newValue
                                try? modelContext.save()
                                WatchConnectivityManager.shared.sendProfileSettingsToPhone(profile)
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Mark Position")
                                    .font(.caption)
                                Text("Save page + line number")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(themeColor.color)
                    } header: {
                        Text("Customization")
                    }

                    Section {
                        Text("Quick sessions are created when you tap +1, +5, etc. Timer sessions are created using the reading timer.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section {
                        Text("Settings are managed from your iPhone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsWatchView()
    }
}

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
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        List {
            Section {
                if let profile = profile {
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
                    .tint(.cyan)
                }
            } header: {
                Text("Session Display")
            }

            Section {
                Text("Quick sessions are created when you tap +1, +5, etc. Timer sessions are created using the reading timer.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

//
//  SessionSettingsView.swift
//  Shlf
//
//  Settings for active session management
//

import SwiftUI
import SwiftData

struct SessionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile
    @State private var showCustomHoursInput = false
    @State private var customHours: String = ""

    private let presetHours: [(label: String, hours: Int)] = [
        ("12 hours", 12),
        ("24 hours", 24),
        ("48 hours", 48),
        ("72 hours", 72)
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Auto-End Inactive Sessions", isOn: $profile.autoEndSessionEnabled)
                    .tint(Theme.Colors.primary)
            } footer: {
                Text("Automatically end reading sessions after a period of inactivity")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            if profile.autoEndSessionEnabled {
                Section("Auto-End After") {
                    ForEach(presetHours, id: \.hours) { preset in
                        Button {
                            profile.autoEndSessionHours = preset.hours
                        } label: {
                            HStack {
                                Text(preset.label)
                                    .foregroundStyle(Theme.Colors.text)
                                Spacer()
                                if profile.autoEndSessionHours == preset.hours {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.Colors.primary)
                                }
                            }
                        }
                    }

                    Button {
                        showCustomHoursInput = true
                        customHours = "\(profile.autoEndSessionHours)"
                    } label: {
                        HStack {
                            Text("Custom")
                                .foregroundStyle(Theme.Colors.text)
                            Spacer()
                            if !presetHours.contains(where: { $0.hours == profile.autoEndSessionHours }) {
                                Text("\(profile.autoEndSessionHours) hours")
                                    .foregroundStyle(Theme.Colors.primary)
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.Colors.primary)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle(isOn: $profile.hideAutoSessionsIPhone) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hide Quick Sessions on iPhone")
                        Text("Only show timer-based sessions in reading history")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                .onChange(of: profile.hideAutoSessionsIPhone) { oldValue, newValue in
                    try? modelContext.save()
                }
                .tint(Theme.Colors.primary)
            } header: {
                Text("Session Display")
            } footer: {
                Text("Quick sessions are created when you tap +1, +5, etc. Timer sessions are created using the reading timer. To control Apple Watch sessions, go to Watch Settings.")
                    .font(Theme.Typography.caption)
            }

            Section {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Theme.Colors.accent)
                        Text("How It Works")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.text)
                    }

                    Text("Active sessions sync between your iPhone and Apple Watch. If a session is inactive for the specified duration, it will automatically end and save your progress.")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Custom Duration", isPresented: $showCustomHoursInput) {
            TextField("Hours", text: $customHours)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                if let hours = Int(customHours), hours > 0 {
                    profile.autoEndSessionHours = hours
                }
            }
        } message: {
            Text("Enter the number of hours after which inactive sessions should auto-end (1-168 hours)")
        }
    }
}

#Preview {
    NavigationStack {
        SessionSettingsView(profile: UserProfile())
    }
}

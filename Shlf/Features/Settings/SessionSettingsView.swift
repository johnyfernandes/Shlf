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
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var showCustomHoursInput = false
    @State private var customHours: String = ""
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    private let presetHours: [(label: String, hours: Int)] = [
        ("12 hours", 12),
        ("24 hours", 24),
        ("48 hours", 48),
        ("72 hours", 72)
    ]

    var body: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background
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
                    // About Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Configure how reading sessions are managed and displayed across your devices.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Auto-End Sessions Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Auto-End Sessions")
                                .font(.headline)
                        }

                        VStack(spacing: 12) {
                            // Toggle
                            Toggle("Auto-End Inactive Sessions", isOn: $profile.autoEndSessionEnabled)
                                .tint(themeColor.color)
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text("Automatically end reading sessions after a period of inactivity")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Auto-End Duration Section (only when enabled)
                    if profile.autoEndSessionEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Auto-End After")
                                    .font(.headline)
                            }

                            VStack(spacing: 10) {
                                // Preset options
                                ForEach(presetHours, id: \.hours) { preset in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            profile.autoEndSessionHours = preset.hours
                                            do {
                                                try modelContext.save()
                                            } catch {
                                                saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                                                showSaveError = true
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(preset.label)
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            if profile.autoEndSessionHours == preset.hours {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(themeColor.color)
                                            }
                                        }
                                        .padding(12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(
                                                    profile.autoEndSessionHours == preset.hours ? themeColor.color : .clear,
                                                    lineWidth: 2
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }

                                // Custom option
                                Button {
                                    showCustomHoursInput = true
                                    customHours = "\(profile.autoEndSessionHours)"
                                } label: {
                                    HStack(spacing: 12) {
                                        Text("Custom")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if !presetHours.contains(where: { $0.hours == profile.autoEndSessionHours }) {
                                            Text("\(profile.autoEndSessionHours) hours")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)

                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(themeColor.color)
                                        } else {
                                            Image(systemName: "ellipsis.circle")
                                                .font(.title3)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(
                                                !presetHours.contains(where: { $0.hours == profile.autoEndSessionHours }) ? themeColor.color : .clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                    }

                    // Session Display Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Session Display")
                                .font(.headline)
                        }

                        VStack(spacing: 12) {
                            Toggle(isOn: $profile.hideAutoSessionsIPhone) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Hide Quick Sessions on iPhone")
                                        .font(.subheadline)
                                    Text("Only show timer-based sessions in reading history")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onChange(of: profile.hideAutoSessionsIPhone) { oldValue, newValue in
                                do {
                                    try modelContext.save()
                                } catch {
                                    saveErrorMessage = "Failed to save setting: \(error.localizedDescription)"
                                    showSaveError = true
                                    profile.hideAutoSessionsIPhone = oldValue
                                }
                            }
                            .tint(themeColor.color)
                            .padding(12)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text("Quick sessions are created when you tap +1, +5, etc. Timer sessions are created using the reading timer. To control Apple Watch sessions, go to Watch Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // How It Works Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("How It Works")
                                .font(.headline)
                        }

                        Text("Active sessions sync between your iPhone and Apple Watch. If a session is inactive for the specified duration, it will automatically end and save your progress.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Custom Duration", isPresented: $showCustomHoursInput) {
            TextField("Hours", text: $customHours)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Set") {
                if let hours = Int(customHours), hours > 0 && hours <= 168 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        profile.autoEndSessionHours = hours
                    }
                    do {
                        try modelContext.save()
                    } catch {
                        saveErrorMessage = "Failed to save setting: \(error.localizedDescription)"
                        showSaveError = true
                    }
                }
            }
        } message: {
            Text("Enter the number of hours after which inactive sessions should auto-end (1-168 hours)")
        }
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }
}

#Preview {
    NavigationStack {
        SessionSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}

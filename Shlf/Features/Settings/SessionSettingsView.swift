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

    private let presetHours: [Int] = [12, 24, 48, 72]

    var body: some View {
        ZStack(alignment: .top) {
            background

            ScrollView {
                VStack(spacing: 20) {
                    aboutSection
                    autoEndSection

                    // Auto-End Duration Section (only when enabled)
                    if profile.autoEndSessionEnabled {
                        autoEndDurationSection
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }

                    sessionDisplaySection
                    howItWorksSection
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

    private var background: some View {
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
    }

    private var aboutSection: some View {
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
    }

    private var autoEndSection: some View {
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
    }

    private var autoEndDurationSection: some View {
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
                ForEach(presetHours, id: \.self) { hours in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            profile.autoEndSessionHours = hours
                            do {
                                try modelContext.save()
                            } catch {
                                saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                                showSaveError = true
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(hoursLabel(hours))
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()

                            if profile.autoEndSessionHours == hours {
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
                                    profile.autoEndSessionHours == hours ? themeColor.color : .clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showCustomHoursInput = true
                    customHours = "\(profile.autoEndSessionHours)"
                } label: {
                    HStack(spacing: 12) {
                        Text("Custom")
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        if !presetHours.contains(where: { $0 == profile.autoEndSessionHours }) {
                            Text(hoursLabel(profile.autoEndSessionHours))
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
                                !presetHours.contains(where: { $0 == profile.autoEndSessionHours }) ? themeColor.color : .clear,
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
    }

    private var sessionDisplaySection: some View {
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
    }

    private var howItWorksSection: some View {
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

    private func hoursLabel(_ hours: Int) -> String {
        String.localizedStringWithFormat(String(localized: "%lld hours"), hours)
    }
}

#Preview {
    NavigationStack {
        SessionSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}

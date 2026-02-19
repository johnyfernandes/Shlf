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
    @Environment(\.locale) private var locale
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
        .navigationTitle("SessionSettings.Title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("SessionSettings.CustomDuration.Title", isPresented: $showCustomHoursInput) {
            TextField("SessionSettings.CustomDuration.Hours", text: $customHours)
                .keyboardType(.numberPad)
            Button("Common.Cancel", role: .cancel) {}
            Button("Common.Set") {
                if let hours = Int(customHours), hours > 0 && hours <= 168 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        profile.autoEndSessionHours = hours
                    }
                    do {
                        try modelContext.save()
                    } catch {
                        saveErrorMessage = String.localizedStringWithFormat(
                            localized("SessionSettings.SaveErrorFormat", locale: locale),
                            error.localizedDescription
                        )
                        showSaveError = true
                    }
                }
            }
        } message: {
            Text("SessionSettings.CustomDuration.Message")
        }
        .alert("SessionSettings.SaveErrorTitle", isPresented: $showSaveError) {
            Button("Common.OK") {}
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

                Text("SessionSettings.AboutTitle")
                    .font(.headline)
            }

            Text("SessionSettings.AboutDescription")
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

                Text("SessionSettings.AutoEnd.Title")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                Toggle("SessionSettings.AutoEnd.Toggle", isOn: $profile.autoEndSessionEnabled)
                    .tint(themeColor.color)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("SessionSettings.AutoEnd.Description")
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

                Text("SessionSettings.AutoEnd.After")
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
                                saveErrorMessage = String.localizedStringWithFormat(
                                    localized("SessionSettings.SaveErrorFormat", locale: locale),
                                    error.localizedDescription
                                )
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
                        Text("SessionSettings.Custom")
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

                Text("SessionSettings.Display.Title")
                    .font(.headline)
            }

            VStack(spacing: 12) {
                Toggle(isOn: $profile.hideAutoSessionsIPhone) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SessionSettings.Display.HideQuick")
                            .font(.subheadline)
                        Text("SessionSettings.Display.HideQuick.Detail")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: profile.hideAutoSessionsIPhone) { oldValue, newValue in
                    do {
                        try modelContext.save()
                    } catch {
                        saveErrorMessage = String.localizedStringWithFormat(
                            localized("SessionSettings.SaveErrorFormat", locale: locale),
                            error.localizedDescription
                        )
                        showSaveError = true
                        profile.hideAutoSessionsIPhone = oldValue
                    }
                }
                .tint(themeColor.color)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("SessionSettings.Display.Footer")
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

                Text("SessionSettings.HowItWorks.Title")
                    .font(.headline)
            }

            Text("SessionSettings.HowItWorks.Description")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func hoursLabel(_ hours: Int) -> String {
        String.localizedStringWithFormat(localized("SessionSettings.HoursFormat", locale: locale), hours)
    }
}

#Preview {
    NavigationStack {
        SessionSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}

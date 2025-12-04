//
//  ThemeColorSettingsView.swift
//  Shlf
//
//  Theme color customization
//

import SwiftUI
import SwiftData

struct ThemeColorSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 16)
    ]

    /// Update Live Activity with new theme color by restarting it
    /// Seamlessly restarts the Live Activity preserving all state except color
    private func updateLiveActivityThemeColor(newThemeColor: ThemeColor) async {
        guard ReadingSessionActivityManager.shared.isActive else {
            return
        }

        guard let currentPage = ReadingSessionActivityManager.shared.getCurrentPage(),
              let currentXP = ReadingSessionActivityManager.shared.getCurrentXP() else {
            return
        }

        let descriptor = FetchDescriptor<ActiveReadingSession>()
        guard let activeSessions = try? modelContext.fetch(descriptor),
              let activeSession = activeSessions.first,
              let book = activeSession.book else {
            return
        }

        let isPaused = activeSession.isPaused
        let newThemeHex = newThemeColor.color.toHex() ?? "#00CED1"

        await ReadingSessionActivityManager.shared.startActivity(
            book: book,
            currentPage: currentPage,
            startPage: activeSession.startPage,
            startTime: activeSession.startDate,
            themeColorHex: newThemeHex
        )

        if isPaused {
            await ReadingSessionActivityManager.shared.pauseActivity()
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background
            LinearGradient(
                colors: [
                    profile.themeColor.color.opacity(0.12),
                    profile.themeColor.color.opacity(0.04),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "paintbrush.fill")
                                .font(.caption)
                                .foregroundStyle(profile.themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Choose your preferred accent color. It will be applied throughout the app and synced to your Apple Watch.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Color Grid
                    VStack(alignment: .leading, spacing: 16) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(ThemeColor.allCases) { themeColor in
                                ColorOption(
                                    themeColor: themeColor,
                                    isSelected: profile.themeColor == themeColor,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            profile.themeColor = themeColor
                                            try? modelContext.save()

                                            WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)

                                            Task {
                                                await updateLiveActivityThemeColor(newThemeColor: themeColor)
                                            }

                                            WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Theme Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ColorOption: View {
    let themeColor: ThemeColor
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor.gradient)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? .white : .clear,
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: isSelected ? themeColor.color.opacity(0.4) : .black.opacity(0.1),
                            radius: isSelected ? 16 : 4,
                            y: isSelected ? 6 : 2
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(themeColor.displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? themeColor.color : .primary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ThemeColorSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}

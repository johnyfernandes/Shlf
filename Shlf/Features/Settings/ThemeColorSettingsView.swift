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
    @Environment(\.locale) private var locale
    @Bindable var profile: UserProfile
    @State private var showUpgradeSheet = false

    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 16)
    ]

    private let freeColors: Set<ThemeColor> = [.neutral, .orange, .blue, .green]

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    /// Update Live Activity with new theme color by restarting it
    /// Seamlessly restarts the Live Activity preserving all state except color
    private func updateLiveActivityThemeColor(newThemeColor: ThemeColor) async {
        guard ReadingSessionActivityManager.shared.isActive else {
            return
        }

        guard let currentPage = ReadingSessionActivityManager.shared.getCurrentPage(),
              ReadingSessionActivityManager.shared.getCurrentXP() != nil else {
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

                            Text("ThemeColorSettings.AboutTitle")
                                .font(.headline)
                        }

                        Text("ThemeColorSettings.AboutDescription")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if !isProUser {
                            Text("ThemeColorSettings.ProNote")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }
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
                                    isFree: freeColors.contains(themeColor),
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            guard isProUser || freeColors.contains(themeColor) else {
                                                showUpgradeSheet = true
                                                return
                                            }
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
        .navigationTitle("ThemeColorSettings.Title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }
}

struct ColorOption: View {
    @Environment(\.colorScheme) private var colorScheme
    let themeColor: ThemeColor
    let isSelected: Bool
    let isFree: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(themeColor.gradient)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? themeColor.onColor(for: colorScheme) : .clear,
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
                            .foregroundStyle(themeColor.onColor(for: colorScheme))
                            .symbolRenderingMode(.hierarchical)
                    }

                    OptionBadge(
                        text: isFree ? "ThemeColorSettings.Badge.Free" : "ThemeColorSettings.Badge.Pro",
                        icon: isFree ? nil : "crown.fill",
                        tint: isFree ? Theme.Colors.success : Color.yellow
                    )
                    .offset(x: 6, y: -6)
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(themeColor.displayNameKey)
                    .font(.caption)
                    .foregroundStyle(isSelected ? themeColor.color : .primary)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OptionBadge: View {
    let text: LocalizedStringKey
    let icon: String?
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint, in: Capsule())
        .shadow(color: tint.opacity(0.25), radius: 4, y: 2)
    }
}

#Preview {
    NavigationStack {
        ThemeColorSettingsView(profile: UserProfile())
    }
    .modelContainer(for: [UserProfile.self], inMemory: true)
}

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

    var body: some View {
        Form {
            Section {
                Text("Choose your preferred accent color. It will be applied throughout the app and synced to your Apple Watch.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(ThemeColor.allCases) { themeColor in
                        ColorOption(
                            themeColor: themeColor,
                            isSelected: profile.themeColor == themeColor,
                            onSelect: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    profile.themeColor = themeColor
                                    try? modelContext.save()

                                    // Sync to Watch immediately
                                    WatchConnectivityManager.shared.sendProfileSettingsToWatch(profile)

                                    // Give haptic feedback
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                }
                            }
                        )
                    }
                }
                .padding(.vertical, Theme.Spacing.sm)
            }
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
            VStack(spacing: Theme.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(themeColor.gradient)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    isSelected ? .white : .clear,
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: isSelected ? themeColor.color.opacity(0.5) : Color.clear,
                            radius: isSelected ? 12 : 0,
                            y: isSelected ? 4 : 0
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)

                Text(themeColor.displayName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(isSelected ? themeColor.color : Theme.Colors.text)
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

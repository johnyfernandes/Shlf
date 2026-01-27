//
//  StatCard.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct StatCard: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let value: String
    let icon: String
    let gradient: LinearGradient?
    var isEditing: Bool = false
    var onRemove: (() -> Void)? = nil

    // Extract primary color from gradient for effects
    private var primaryColor: Color {
        // Default colors based on common gradients
        if gradient != nil {
            // Keep streak gradient (orange/red)
            if icon.contains("flame") {
                return Color.orange
            }
            // Everything else with gradient uses theme color
            else {
                return themeColor.color
            }
        }
        return Theme.Colors.accent
    }

    private var iconForeground: Color {
        if icon.contains("flame") {
            return .white
        }
        if gradient != nil {
            return themeColor.onColor(for: colorScheme)
        }
        return Theme.Colors.accent
    }

    init(
        title: LocalizedStringKey,
        value: String,
        icon: String,
        gradient: LinearGradient? = nil,
        isEditing: Bool = false,
        onRemove: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.gradient = gradient
        self.isEditing = isEditing
        self.onRemove = onRemove
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 10) {
                // Icon on left
                ZStack {
                    if let gradient {
                        Circle()
                            .fill(
                                // Keep flame icons with original gradient, everything else uses theme color
                                icon.contains("flame")
                                    ? gradient
                                    : LinearGradient(
                                        colors: [
                                            themeColor.color,
                                            themeColor.color.opacity(0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(
                                color: primaryColor.opacity(0.3),
                                radius: 6,
                                x: 0,
                                y: 3
                            )

                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                            .foregroundStyle(iconForeground)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.Colors.accent.opacity(0.2),
                                        Theme.Colors.accent.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                }

                // Value and title on right
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())

                    Text(title)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.4)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Base glassmorphic background
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)

                    // Subtle gradient overlay for depth
                    if gradient != nil {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        primaryColor.opacity(0.08),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (gradient != nil ? primaryColor.opacity(0.2) : Theme.Colors.accent.opacity(0.1)),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .modifier(WiggleModifier(isWiggling: isEditing))

            // Remove button (shown in edit mode)
            if isEditing, let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white, Color.red)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .offset(x: 8, y: -8)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

// Wiggle animation modifier (like iOS home screen)
struct WiggleModifier: ViewModifier {
    let isWiggling: Bool
    @State private var rotationAngle: Double = 0

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(isWiggling ? rotationAngle : 0))
            .animation(
                isWiggling
                    ? Animation.easeInOut(duration: 0.14)
                        .repeatForever(autoreverses: true)
                    : .default,
                value: isWiggling
            )
            .onChange(of: isWiggling) { _, newValue in
                if newValue {
                    rotationAngle = [-1.5, 1.5].randomElement() ?? 0
                } else {
                    rotationAngle = 0
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            StatCard(
                title: "Day Streak",
                value: "12",
                icon: "flame.fill",
                gradient: Theme.Colors.streakGradient
            )

            StatCard(
                title: "Level",
                value: "5",
                icon: "star.fill",
                gradient: Theme.Colors.xpGradient
            )
        }

        HStack(spacing: 16) {
            StatCard(
                title: "Finished",
                value: "23",
                icon: "books.vertical.fill",
                gradient: Theme.Colors.successGradient
            )

            StatCard(
                title: "Pages",
                value: "1,234",
                icon: "doc.text.fill"
            )
        }
    }
    .padding()
    .background(Theme.Colors.background)
}

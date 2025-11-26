//
//  StatCard.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient?
    var isEditing: Bool = false
    var onRemove: (() -> Void)? = nil

    init(
        title: String,
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
            HStack(spacing: Theme.Spacing.xs) {
                // Icon
                ZStack {
                    if let gradient {
                        Circle()
                            .fill(gradient)
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }

                // Value and title
                VStack(alignment: .leading, spacing: 1) {
                    Text(value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())

                    Text(title)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(elevation: Theme.Elevation.level2)
            .modifier(WiggleModifier(isWiggling: isEditing))

            // Remove button (shown in edit mode)
            if isEditing, let onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, Color.red)
                }
                .offset(x: 6, y: -6)
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
        StatCard(
            title: "Current Streak",
            value: "12 days",
            icon: "flame.fill",
            gradient: Theme.Colors.streakGradient
        )

        StatCard(
            title: "Books Read",
            value: "23",
            icon: "books.vertical.fill"
        )

        StatCard(
            title: "Level",
            value: "5",
            icon: "star.fill",
            gradient: Theme.Colors.xpGradient
        )
    }
    .padding()
}

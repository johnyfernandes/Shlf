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

    init(
        title: String,
        value: String,
        icon: String,
        gradient: LinearGradient? = nil
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.gradient = gradient
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                ZStack {
                    if let gradient {
                        Circle()
                            .fill(gradient)
                            .frame(width: 48, height: 48)

                        Image(systemName: icon)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    } else {
                        Circle()
                            .fill(Theme.Colors.primary.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: icon)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }

                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(value)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.text)
                    .contentTransition(.numericText())

                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140)
        .cardStyle(elevation: Theme.Elevation.level2)
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

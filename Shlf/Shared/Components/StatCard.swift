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
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            ZStack {
                if let gradient {
                    Circle()
                        .fill(gradient)
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }

            // Value and title
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
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

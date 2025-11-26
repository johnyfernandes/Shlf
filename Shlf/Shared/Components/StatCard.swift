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
        HStack(spacing: Theme.Spacing.sm) {
            // Icon
            ZStack {
                if let gradient {
                    Circle()
                        .fill(gradient)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(Theme.Colors.primary.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 19))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.primary)
                }
            }

            // Value and title
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())

                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.sm)
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

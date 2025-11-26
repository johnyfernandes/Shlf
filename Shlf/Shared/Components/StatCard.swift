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
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                if let gradient {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(gradient)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Theme.Colors.primary)
                }

                Spacer()
            }

            Text(value)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.text)

            Text(title)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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

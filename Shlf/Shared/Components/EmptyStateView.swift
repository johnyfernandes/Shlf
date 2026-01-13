//
//  EmptyStateView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct EmptyStateView: View {
    @Environment(\.themeColor) private var themeColor

    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(themeColor.color.opacity(0.08))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(themeColor.color.opacity(0.05))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 48))
                    .fontWeight(.medium)
                    .foregroundStyle(themeColor.color.opacity(0.6))
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.text)

                Text(message)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.lg)
            }

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)

                        Text(actionTitle)
                    }
                    .primaryButton(color: themeColor.color)
                }
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    EmptyStateView(
        icon: "books.vertical",
        title: "No Books Yet",
        message: "Add your first book to start tracking your reading journey",
        actionTitle: "Add Book",
        action: {}
    )
}

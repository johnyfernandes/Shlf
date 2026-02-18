//
//  EmptyStateView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct EmptyStateView: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let titleKey: LocalizedStringKey?
    let messageKey: LocalizedStringKey?
    let actionTitleKey: LocalizedStringKey?
    let titleString: String?
    let messageString: String?
    let actionTitleString: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.titleKey = title
        self.messageKey = message
        self.actionTitleKey = actionTitle
        self.titleString = nil
        self.messageString = nil
        self.actionTitleString = nil
        self.action = action
    }

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.titleKey = nil
        self.messageKey = nil
        self.actionTitleKey = nil
        self.titleString = title
        self.messageString = message
        self.actionTitleString = actionTitle
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
                Group {
                    if let titleString {
                        Text(verbatim: titleString)
                    } else if let titleKey {
                        Text(titleKey)
                    }
                }
                .font(Theme.Typography.title2)
                .foregroundStyle(Theme.Colors.text)

                Group {
                    if let messageString {
                        Text(verbatim: messageString)
                    } else if let messageKey {
                        Text(messageKey)
                    }
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.lg)
            }

            if let action {
                Button(action: action) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)

                        if let actionTitleString {
                            Text(verbatim: actionTitleString)
                        } else if let actionTitleKey {
                            Text(actionTitleKey)
                        }
                    }
                    .primaryButton(color: themeColor.color, foreground: themeColor.onColor(for: colorScheme))
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

//
//  InlineEmptyStateView.swift
//  Shlf
//
//  Compact empty-state component for inline cards/sections.
//

import SwiftUI

struct InlineEmptyStateView: View {
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
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(themeColor.color.opacity(0.12))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeColor.color)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.text)

                Text(message)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                if let actionTitle, let action {
                    Button(actionTitle) {
                        action()
                    }
                    .font(Theme.Typography.caption.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    InlineEmptyStateView(
        icon: "quote.bubble",
        title: "No quotes yet",
        message: "Save a quote from your next session.",
        actionTitle: "Add quote",
        action: {}
    )
    .padding()
}

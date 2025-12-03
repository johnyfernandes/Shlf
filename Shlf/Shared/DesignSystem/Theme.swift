//
//  Theme.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

enum Theme {
    // MARK: - Colors

    enum Colors {
        // Primary palette - vibrant and modern
        static let primary = Color(red: 0.0, green: 0.48, blue: 1.0) // iOS Blue
        static let secondary = Color(red: 0.69, green: 0.32, blue: 0.87) // Purple
        static let accent = Color(red: 1.0, green: 0.58, blue: 0.0) // Orange

        // Backgrounds - adaptive
        static let background = Color(uiColor: .systemBackground)
        static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

        // Text colors
        static let text = Color.primary
        static let secondaryText = Color.secondary
        static let tertiaryText = Color(uiColor: .tertiaryLabel)

        // Semantic colors
        static let success = Color(red: 0.20, green: 0.78, blue: 0.35) // Green
        static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // Orange
        static let error = Color(red: 1.0, green: 0.27, blue: 0.23) // Red

        // Gradients - modern and vibrant
        static let xpGradient = LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.48, blue: 1.0),
                Color(red: 0.35, green: 0.34, blue: 0.84),
                Color(red: 0.69, green: 0.32, blue: 0.87)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let streakGradient = LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.58, blue: 0.0),
                Color(red: 1.0, green: 0.27, blue: 0.23)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let successGradient = LinearGradient(
            colors: [
                Color(red: 0.20, green: 0.78, blue: 0.35),
                Color(red: 0.0, green: 0.78, blue: 0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let heroGradient = LinearGradient(
            colors: [
                Color(red: 0.0, green: 0.48, blue: 1.0).opacity(0.1),
                Color(red: 0.69, green: 0.32, blue: 0.87).opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        static let xxxl: CGFloat = 64
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let full: CGFloat = 999
    }

    // MARK: - Animations

    enum Animation {
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.75)
        static let snappy = SwiftUI.Animation.snappy(duration: 0.25)
        static let smooth = SwiftUI.Animation.smooth(duration: 0.3)
        static let bouncy = SwiftUI.Animation.bouncy(duration: 0.4)
    }

    // MARK: - Shadows

    enum Shadow {
        static let small = Color.black.opacity(0.08)
        static let medium = Color.black.opacity(0.12)
        static let large = Color.black.opacity(0.18)
        static let xl = Color.black.opacity(0.25)
    }

    // MARK: - Elevation

    enum Elevation {
        static let level1: CGFloat = 2
        static let level2: CGFloat = 4
        static let level3: CGFloat = 8
        static let level4: CGFloat = 12
    }
}

// MARK: - View Extensions

extension View {
    // MARK: - Card Styles

    func cardStyle(elevation: CGFloat = Theme.Elevation.level2) -> some View {
        self
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.small, radius: elevation, y: elevation / 2)
    }

    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.medium, radius: Theme.Elevation.level2, y: 2)
    }

    func heroCard() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                    .fill(Theme.Colors.heroGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                            .stroke(Theme.Colors.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(color: Theme.Shadow.medium, radius: Theme.Elevation.level3, y: 4)
    }

    // MARK: - Button Styles

    func primaryButton(fullWidth: Bool = false, color: Color? = nil) -> some View {
        let buttonColor = color ?? Theme.Colors.primary
        return self
            .font(Theme.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(buttonColor)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
            .shadow(color: buttonColor.opacity(0.3), radius: 8, y: 4)
    }

    func secondaryButton(fullWidth: Bool = false) -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.primary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                    .stroke(Theme.Colors.primary.opacity(0.2), lineWidth: 1.5)
            )
    }

    func tertiaryButton(fullWidth: Bool = false) -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.primary)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
    }

    func ghostButton() -> some View {
        self
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
    }

    func pillButton() -> some View {
        self
            .font(Theme.Typography.subheadline)
            .foregroundStyle(Theme.Colors.primary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Colors.primary.opacity(0.1))
            .clipShape(Capsule())
    }

    func iconButton(size: CGFloat = 44) -> some View {
        self
            .frame(width: size, height: size)
            .background(Theme.Colors.secondaryBackground)
            .clipShape(Circle())
            .shadow(color: Theme.Shadow.small, radius: Theme.Elevation.level1, y: 1)
    }

    // MARK: - Interactive States

    func pressableScale() -> some View {
        self
            .scaleEffect(1.0)
            .animation(Theme.Animation.snappy, value: UUID())
    }

    // MARK: - Utility

    func sectionHeader() -> some View {
        self
            .font(Theme.Typography.title3)
            .foregroundStyle(Theme.Colors.text)
    }
}

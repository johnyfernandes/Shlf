//
//  PaywallView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import StoreKit
#if canImport(UIKit)
import UIKit
#endif

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale
    @Query private var profiles: [UserProfile]
    @State private var storeKit = StoreKitService.shared
    @State private var isPurchasing = false
    @State private var selectedPlan: PaywallPlan = .yearly

    private var selectedProduct: Product? {
        storeKit.product(for: selectedPlan.productID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    heroSection
                    featuresSection
                    planSection
                    actionSection
                    legalSection
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .task {
                await storeKit.loadProducts()
                if storeKit.product(for: selectedPlan.productID) == nil {
                    selectedPlan = PaywallPlan.bestDefaultPlan(
                        monthlyAvailable: storeKit.product(for: PaywallPlan.monthly.productID) != nil,
                        yearlyAvailable: storeKit.product(for: PaywallPlan.yearly.productID) != nil,
                        lifetimeAvailable: storeKit.product(for: PaywallPlan.lifetime.productID) != nil
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("Done", locale: locale)) {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            PaywallHeroCard(
                accent: themeColor.color,
                colorScheme: colorScheme,
                iconImage: currentAppIconImage,
                badgeColor: currentAppIconAccent.color,
                badgeIsLight: currentAppIconAccent.isLight,
                badges: [
                    localized("Paywall.Badge.Live", locale: locale),
                    localized("Paywall.Badge.Stats", locale: locale),
                    localized("Paywall.Badge.Watch", locale: locale),
                    localized("Paywall.Badge.Sync", locale: locale)
                ]
            )
                .frame(maxWidth: .infinity)

            Text(localized("Paywall.Header.Title", locale: locale))
                .font(Theme.Typography.largeTitle)
                .multilineTextAlignment(.center)

            Text(localized("Paywall.Header.Subtitle", locale: locale))
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            PaywallSectionHeader(
                title: localized("Paywall.Features.Title", locale: locale),
                subtitle: localized("Paywall.Features.Subtitle", locale: locale)
            )

            VStack(spacing: Theme.Spacing.sm) {
                PaywallFeatureRow(icon: "books.vertical.fill", text: localized("Paywall.Feature.UnlimitedBooks", locale: locale))
                PaywallFeatureRow(icon: "bolt.horizontal.fill", text: localized("Paywall.Feature.LiveActivities", locale: locale))
                PaywallFeatureRow(icon: "applewatch", text: localized("Paywall.Feature.Watch", locale: locale))
                PaywallFeatureRow(icon: "chart.bar.xaxis", text: localized("Paywall.Feature.AdvancedStats", locale: locale))
                PaywallFeatureRow(icon: "paintbrush.fill", text: localized("Paywall.Feature.Themes", locale: locale))
                PaywallFeatureRow(icon: "icloud.fill", text: localized("Paywall.Feature.iCloud", locale: locale))
                PaywallFeatureRow(icon: "arrow.down.doc.fill", text: localized("Paywall.Feature.Import", locale: locale))
            }
            .padding(Theme.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        }
    }

    private var planSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            PaywallSectionHeader(
                title: localized("Paywall.Plans.Title", locale: locale),
                subtitle: localized("Paywall.Plans.Subtitle", locale: locale)
            )

            VStack(spacing: Theme.Spacing.sm) {
                ForEach(PaywallPlan.ordered, id: \.self) { plan in
                    Button {
                        selectedPlan = plan
                    } label: {
                        PaywallPlanCard(
                            plan: plan,
                            title: plan.title(locale: locale),
                            subtitle: plan.subtitle(locale: locale),
                            priceText: storeKit.product(for: plan.productID)?.displayPrice ?? "--",
                            periodText: plan.periodText(locale: locale),
                            badgeText: badgeText(for: plan),
                            isSelected: selectedPlan == plan,
                            isRecommended: plan == .yearly,
                            accentColor: themeColor.color,
                            isNeutralTheme: themeColor == .neutral,
                            colorScheme: colorScheme
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(storeKit.product(for: plan.productID) == nil && storeKit.isLoadingProducts)
                }
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if storeKit.isLoadingProducts {
                ProgressView()
            } else if let error = storeKit.lastLoadError {
                VStack(spacing: Theme.Spacing.xs) {
                    Text(localized("Paywall.Error.Load", locale: locale))
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)

                    Text(error)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .multilineTextAlignment(.center)

                    Button(localized("Try Again", locale: locale)) {
                        Task { await storeKit.loadProducts() }
                    }
                    .font(Theme.Typography.callout)
                    .foregroundStyle(themeColor.color)
                }
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    if let product = selectedProduct {
                        purchase(product)
                    }
                } label: {
                    if isPurchasing {
                        ProgressView()
                            .tint(themeColor.onColor(for: colorScheme))
                    } else if let product = selectedProduct {
                        let title = String.localizedStringWithFormat(
                            localized("Paywall.CTA", locale: locale),
                            selectedPlan.title(locale: locale),
                            product.displayPrice
                        )
                        Text(title)
                            .font(Theme.Typography.headline)
                    } else {
                        Text(localized("Paywall.NoProducts", locale: locale))
                            .font(Theme.Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .primaryButton(color: themeColor.color, foreground: themeColor.onColor(for: colorScheme))
                .disabled(isPurchasing || selectedProduct == nil)

                Button(localized("Restore Purchases", locale: locale)) {
                    Task {
                        await storeKit.restorePurchases()
                        if let profile = profiles.first {
                            profile.isProUser = storeKit.isProUser
                            try? modelContext.save()
                        }
                    }
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(themeColor.color)

                Button(localized("Manage Subscription", locale: locale)) {
                    openSubscriptions()
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(themeColor.color)

                Text(selectedPlan.footerText(locale: locale))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }

            Button(localized("Not now", locale: locale)) {
                dismiss()
            }
            .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private var legalSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Link(localized("Terms", locale: locale), destination: URL(string: "https://shlf.app/terms")!)
            Text(verbatim: "•")
                .foregroundStyle(Theme.Colors.tertiaryText)
            Link(localized("Privacy", locale: locale), destination: URL(string: "https://shlf.app/privacy")!)
        }
        .font(Theme.Typography.caption)
        .foregroundStyle(Theme.Colors.tertiaryText)
    }

    private func purchase(_ product: Product) {
        isPurchasing = true

        Task {
            do {
                try await storeKit.purchase(product)
                if let profile = profiles.first {
                    profile.isProUser = storeKit.isProUser
                    try? modelContext.save()
                }
                dismiss()
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }

    private func openSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }

    private var currentAppIconImage: UIImage? {
        #if canImport(UIKit)
        #if targetEnvironment(simulator)
        let iconName = UserDefaults.standard.string(forKey: "Shlf.simulatorAppIconName")
        #else
        let iconName = UIApplication.shared.alternateIconName
        #endif
        let previewName: String
        switch iconName {
        case "AppIcon-Yellow":
            previewName = "AppIconPreview-Yellow"
        case "AppIcon-Gray":
            previewName = "AppIconPreview-Gray"
        case "AppIcon-Pink":
            previewName = "AppIconPreview-Pink"
        case "AppIcon-Purple":
            previewName = "AppIconPreview-Purple"
        case "AppIcon-Black":
            previewName = "AppIconPreview-Black"
        case "AppIcon-Blue":
            previewName = "AppIconPreview-Blue"
        case "AppIcon-Red":
            previewName = "AppIconPreview-Red"
        case "AppIcon-Green":
            previewName = "AppIconPreview-Green"
        case "AppIcon-White":
            previewName = "AppIconPreview-White"
        default:
            previewName = "AppIconPreview-Orange"
        }
        return UIImage(named: previewName)
        #else
        return nil
        #endif
    }

    private var currentAppIconAccent: (color: Color, isLight: Bool) {
        #if canImport(UIKit)
        #if targetEnvironment(simulator)
        let iconName = UserDefaults.standard.string(forKey: "Shlf.simulatorAppIconName")
        #else
        let iconName = UIApplication.shared.alternateIconName
        #endif
        switch iconName {
        case "AppIcon-Yellow":
            return (Color.yellow, true)
        case "AppIcon-Gray":
            return (Color.gray, true)
        case "AppIcon-Pink":
            return (Color.pink, true)
        case "AppIcon-Purple":
            return (Color.purple, false)
        case "AppIcon-Black":
            return (Color.black, false)
        case "AppIcon-Blue":
            return (Color.blue, false)
        case "AppIcon-Red":
            return (Color.red, false)
        case "AppIcon-Green":
            return (Color.green, false)
        case "AppIcon-White":
            return (Color.white, true)
        default:
            return (Color.orange, false)
        }
        #else
        return (Color.orange, false)
        #endif
    }

    private func badgeText(for plan: PaywallPlan) -> String? {
        guard plan == .yearly else {
            return plan == .lifetime ? localized("Paywall.Badge.OneTime", locale: locale) : nil
        }
        guard let monthly = storeKit.product(for: PaywallPlan.monthly.productID)?.price,
              let yearly = storeKit.product(for: PaywallPlan.yearly.productID)?.price else {
            return localized("Paywall.Badge.BestValue", locale: locale)
        }

        let monthlyValue = NSDecimalNumber(decimal: monthly).doubleValue
        let yearlyValue = NSDecimalNumber(decimal: yearly).doubleValue
        guard monthlyValue > 0 else { return localized("Paywall.Badge.BestValue", locale: locale) }

        let annualEquivalent = monthlyValue * 12.0
        guard annualEquivalent > 0 else { return localized("Paywall.Badge.BestValue", locale: locale) }

        let savings = max(0, 1.0 - (yearlyValue / annualEquivalent))
        let percent = Int(round(savings * 100))
        if percent >= 5 {
            let format = localized("Paywall.Badge.SavePercent", locale: locale)
            return String.localizedStringWithFormat(format, percent)
        }
        return localized("Paywall.Badge.BestValue", locale: locale)
    }
}

enum PaywallPlan: CaseIterable {
    case yearly
    case monthly
    case lifetime

    static let ordered: [PaywallPlan] = [.monthly, .yearly, .lifetime]

    var productID: String {
        switch self {
        case .monthly:
            return StoreKitService.monthlyProductID
        case .yearly:
            return StoreKitService.yearlyProductID
        case .lifetime:
            return StoreKitService.lifetimeProductID
        }
    }

    func title(locale: Locale) -> String {
        switch self {
        case .monthly:
            return localized("Paywall.Plan.Monthly", locale: locale)
        case .yearly:
            return localized("Paywall.Plan.Yearly", locale: locale)
        case .lifetime:
            return localized("Paywall.Plan.Lifetime", locale: locale)
        }
    }

    func subtitle(locale: Locale) -> String {
        switch self {
        case .monthly:
            return localized("Paywall.Plan.Monthly.Subtitle", locale: locale)
        case .yearly:
            return localized("Paywall.Plan.Yearly.Subtitle", locale: locale)
        case .lifetime:
            return localized("Paywall.Plan.Lifetime.Subtitle", locale: locale)
        }
    }

    func periodText(locale: Locale) -> String {
        switch self {
        case .monthly:
            return localized("Paywall.Plan.Monthly.Period", locale: locale)
        case .yearly:
            return localized("Paywall.Plan.Yearly.Period", locale: locale)
        case .lifetime:
            return localized("Paywall.Plan.Lifetime.Period", locale: locale)
        }
    }

    func footerText(locale: Locale) -> String {
        switch self {
        case .monthly, .yearly:
            return localized("Paywall.Footer.Recurring", locale: locale)
        case .lifetime:
            return localized("Paywall.Footer.OneTime", locale: locale)
        }
    }

    static func bestDefaultPlan(
        monthlyAvailable: Bool,
        yearlyAvailable: Bool,
        lifetimeAvailable: Bool
    ) -> PaywallPlan {
        if yearlyAvailable { return .yearly }
        if monthlyAvailable { return .monthly }
        if lifetimeAvailable { return .lifetime }
        return .yearly
    }
}

private struct PaywallHeroCard: View {
    let accent: Color
    let colorScheme: ColorScheme
    let iconImage: UIImage?
    let badgeColor: Color
    let badgeIsLight: Bool
    let badges: [String]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                .fill(heroBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.xl, style: .continuous)
                        .stroke(accent.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
                )

            VStack(spacing: Theme.Spacing.md) {
                ZStack(alignment: .topTrailing) {
                    if let iconImage {
                        Image(uiImage: iconImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 132)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.2), radius: 10, y: 5)
                    } else {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.7))
                            .frame(width: 132, height: 132)
                            .overlay(
                                Image(systemName: "book.pages.fill")
                                    .font(.system(size: 34, weight: .semibold))
                                    .foregroundStyle(accent)
                            )
                    }

                    ProGlowBadge(color: badgeColor, isLight: badgeIsLight)
                        .offset(x: 8, y: -8)
                }

                Text("Shlf Pro")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(badges, id: \.self) { badge in
                        PaywallBadge(text: badge)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .shadow(color: Theme.Shadow.medium, radius: Theme.Elevation.level3, y: 6)
    }

    private var heroBackground: LinearGradient {
        let base = accent.opacity(colorScheme == .dark ? 0.22 : 0.16)
        let secondary = accent.opacity(colorScheme == .dark ? 0.08 : 0.05)
        return LinearGradient(
            colors: [base, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct PaywallBadge: View {
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.text)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Theme.Colors.secondaryBackground.opacity(colorScheme == .dark ? 0.55 : 0.85))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(themeColor.color.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: themeColor.color.opacity(0.15), radius: 6, y: 2)
    }
}

private struct ProGlowBadge: View {
    let color: Color
    let isLight: Bool
    @State private var animate = false

    var body: some View {
        Text("Pro")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isLight ? Color.black.opacity(0.85) : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(isLight ? 0.9 : 0.95),
                                color.opacity(isLight ? 0.75 : 0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isLight ? Color.black.opacity(0.2) : Color.white.opacity(0.6), lineWidth: 0.8)
            )
            .shadow(color: color.opacity(isLight ? 0.35 : 0.85), radius: 10, y: 3)
            .shadow(color: color.opacity(isLight ? 0.25 : 0.75), radius: 14, y: 0)
            .overlay(alignment: .topLeading) {
                Sparkle(color: .white.opacity(0.9), size: 10, delay: 0.0, animate: $animate)
                    .offset(x: -6, y: -6)
            }
            .overlay(alignment: .bottomTrailing) {
                Sparkle(color: .white.opacity(0.8), size: 8, delay: 0.9, animate: $animate)
                    .offset(x: 8, y: 6)
            }
            .onAppear { animate = true }
    }

    private struct Sparkle: View {
        let color: Color
        let size: CGFloat
        let delay: Double
        @Binding var animate: Bool

        var body: some View {
            Image(systemName: "sparkles")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(color)
                .opacity(animate ? 1 : 0.2)
                .scaleEffect(animate ? 1.0 : 0.6)
                .rotationEffect(.degrees(animate ? 12 : -8))
                .animation(
                    .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: true)
                        .delay(delay),
                    value: animate
                )
        }
    }
}

private struct PaywallSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

            Text(subtitle)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }
}

struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let title: String
    let subtitle: String
    let priceText: String
    let periodText: String
    let badgeText: String?
    let isSelected: Bool
    let isRecommended: Bool
    let accentColor: Color
    let isNeutralTheme: Bool
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.md) {
            selectionIndicator

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)

                    if let badge = badgeText {
                        Text(badge)
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(badgeForeground)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(badgeBackground, in: Capsule())
                    }
                }

                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer(minLength: Theme.Spacing.sm)

            VStack(alignment: .trailing, spacing: 2) {
                Text(priceText)
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.text)
                Text(periodText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 86)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .shadow(color: Theme.Shadow.small, radius: Theme.Elevation.level1, y: 2)
    }

    private var backgroundColor: Color {
        if isSelected {
            return accentColor.opacity(0.14)
        }
        if isRecommended {
            return accentColor.opacity(0.08)
        }
        return Theme.Colors.secondaryBackground
    }

    private var borderColor: Color {
        if isSelected {
            return accentColor
        }
        if isRecommended {
            return accentColor.opacity(0.4)
        }
        return Theme.Colors.tertiaryText.opacity(0.2)
    }

    private var badgeBackground: Color {
        guard isNeutralTheme else {
            return isRecommended ? accentColor : accentColor.opacity(0.15)
        }
        if isRecommended {
            return colorScheme == .dark ? .white : .black
        }
        return colorScheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.08)
    }

    private var badgeForeground: Color {
        guard isNeutralTheme else {
            return isRecommended ? .white : accentColor
        }
        if isRecommended {
            return colorScheme == .dark ? .black : .white
        }
        return Theme.Colors.text
    }

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
                .frame(width: 18, height: 18)
            if isSelected {
                Circle()
                    .fill(accentColor)
                    .frame(width: 10, height: 10)
            }
        }
        .frame(width: 22, height: 22)
    }
}

struct PaywallFeatureRow: View {
    @Environment(\.themeColor) private var themeColor
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(themeColor.color)
                .frame(width: 28)

            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.text)

            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

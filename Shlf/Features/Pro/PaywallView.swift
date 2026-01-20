//
//  PaywallView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
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
                    featureSection
                    planSection
                    actionSection
                }
                .padding(Theme.Spacing.xl)
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
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)

            Text("Upgrade to Pro")
                .font(Theme.Typography.largeTitle)

            Text("Unlock the full Shlf experience")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private var featureSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            PaywallFeatureRow(icon: "books.vertical.fill", text: "Unlimited books")
            PaywallFeatureRow(icon: "chart.bar.fill", text: "Advanced statistics")
            PaywallFeatureRow(icon: "target", text: "Custom reading goals")
            PaywallFeatureRow(icon: "paintbrush.fill", text: "Themes & customization")
            PaywallFeatureRow(icon: "cloud.fill", text: "Priority iCloud sync")
        }
        .padding(Theme.Spacing.lg)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var planSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(PaywallPlan.ordered, id: \.self) { plan in
                Button {
                    selectedPlan = plan
                } label: {
                    PaywallPlanCard(
                        plan: plan,
                        priceText: storeKit.product(for: plan.productID)?.displayPrice ?? "--",
                        badgeText: badgeText(for: plan),
                        isSelected: selectedPlan == plan,
                        accentColor: themeColor.color
                    )
                }
                .buttonStyle(.plain)
                .disabled(storeKit.product(for: plan.productID) == nil && storeKit.isLoadingProducts)
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if storeKit.isLoadingProducts {
                ProgressView()
            } else if let error = storeKit.lastLoadError {
                VStack(spacing: Theme.Spacing.xs) {
                    Text("Unable to load purchase options")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .multilineTextAlignment(.center)

                    Text(error)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
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
                            .tint(.white)
                    } else if let product = selectedProduct {
                        Text("Continue with \(selectedPlan.title) - \(product.displayPrice)")
                            .font(Theme.Typography.headline)
                    } else {
                        Text("No products available")
                            .font(Theme.Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .primaryButton(color: themeColor.color)
                .disabled(isPurchasing || selectedProduct == nil)

                Button("Restore Purchases") {
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

                Button("Manage Subscription") {
                    openSubscriptions()
                }
                .font(Theme.Typography.callout)
                .foregroundStyle(themeColor.color)

                Text(selectedPlan.footerText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }

            Button("Not now") {
                dismiss()
            }
            .foregroundStyle(Theme.Colors.secondaryText)

            HStack(spacing: Theme.Spacing.sm) {
                Link("Terms", destination: URL(string: "https://shlf.app/terms")!)
                Text(verbatim: "•")
                    .foregroundStyle(Theme.Colors.tertiaryText)
                Link("Privacy", destination: URL(string: "https://shlf.app/privacy")!)
            }
            .font(Theme.Typography.caption)
            .foregroundStyle(Theme.Colors.tertiaryText)
        }
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

    private func badgeText(for plan: PaywallPlan) -> String? {
        guard plan == .yearly else { return nil }
        guard let monthly = storeKit.product(for: PaywallPlan.monthly.productID)?.price,
              let yearly = storeKit.product(for: PaywallPlan.yearly.productID)?.price else {
            return "Best Value"
        }

        let monthlyValue = NSDecimalNumber(decimal: monthly).doubleValue
        let yearlyValue = NSDecimalNumber(decimal: yearly).doubleValue
        guard monthlyValue > 0 else { return "Best Value" }

        let annualEquivalent = monthlyValue * 12.0
        guard annualEquivalent > 0 else { return "Best Value" }

        let savings = max(0, 1.0 - (yearlyValue / annualEquivalent))
        let percent = Int(round(savings * 100))
        if percent >= 5 {
            return "Save \(percent)%"
        }
        return "Best Value"
    }
}

enum PaywallPlan: CaseIterable {
    case yearly
    case monthly
    case lifetime

    static let ordered: [PaywallPlan] = [.yearly, .monthly, .lifetime]

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

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .lifetime: return "Lifetime"
        }
    }

    var subtitle: String {
        switch self {
        case .monthly: return "Flexible, billed monthly"
        case .yearly: return "Best value for readers"
        case .lifetime: return "One-time purchase"
        }
    }

    var periodText: String {
        switch self {
        case .monthly: return "per month"
        case .yearly: return "per year"
        case .lifetime: return "one-time"
        }
    }

    var footerText: String {
        switch self {
        case .monthly, .yearly:
            return "Recurring, cancel anytime."
        case .lifetime:
            return "One-time purchase. Yours forever."
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

struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let priceText: String
    let badgeText: String?
    let isSelected: Bool
    let accentColor: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(plan.title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)

                    if let badge = badgeText {
                        Text(badge)
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Theme.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(accentColor, in: Capsule())
                    }

                    Spacer()
                }

                Text(plan.subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text(priceText)
                        .font(Theme.Typography.title3)
                        .foregroundStyle(Theme.Colors.text)

                    Text(plan.periodText)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return accentColor.opacity(0.12)
        }
        if plan == .yearly {
            return accentColor.opacity(0.06)
        }
        return Theme.Colors.secondaryBackground
    }

    private var borderColor: Color {
        if isSelected {
            return accentColor
        }
        if plan == .yearly {
            return accentColor.opacity(0.35)
        }
        return Theme.Colors.tertiaryText.opacity(0.2)
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
                .frame(width: 30)

            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.text)

            Spacer()
        }
    }
}

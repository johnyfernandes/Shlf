//
//  SettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Query private var profiles: [UserProfile]

    @State private var storeKit = StoreKitService.shared
    @State private var showUpgradeSheet = false
    @State private var showRestoreAlert = false

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let new = UserProfile()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section("Sync") {
                    Toggle("iCloud Sync", isOn: Binding(
                        get: { profile.cloudSyncEnabled },
                        set: { profile.cloudSyncEnabled = $0 }
                    ))

                    if profile.cloudSyncEnabled {
                        Label("Your books sync across devices", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.success)
                    }
                }

                Section("App") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About Shlf", systemImage: "info.circle")
                    }

                    Link(destination: URL(string: "https://shlf.app")!) {
                        Label("Visit shlf.app", systemImage: "safari")
                    }

                    Button {
                        requestReview()
                    } label: {
                        Label("Rate Shlf", systemImage: "star")
                    }
                }

                Section("Data") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Data Management", systemImage: "folder")
                    }
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeView()
            }
            .alert("Restore Complete", isPresented: $showRestoreAlert) {
                Button("OK") {}
            } message: {
                Text("Your purchases have been restored.")
            }
            .task {
                await storeKit.loadProducts()
            }
        }
    }

    private var proSection: some View {
        Section {
            if storeKit.isProUser || profile.isProUser {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)

                    Text("Shlf Pro")
                        .font(Theme.Typography.headline)

                    Spacer()

                    Text("Active")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.success)
                }
            } else {
                Button {
                    showUpgradeSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)

                                Text("Upgrade to Pro")
                                    .font(Theme.Typography.headline)
                            }

                            Text("Unlimited books & features")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        await storeKit.restorePurchases()
                        showRestoreAlert = true

                        if storeKit.isProUser {
                            profile.isProUser = true
                        }
                    }
                }
            }
        }
    }

}

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var storeKit = StoreKitService.shared
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

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

                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    FeatureRow(icon: "books.vertical.fill", text: "Unlimited books")
                    FeatureRow(icon: "chart.bar.fill", text: "Advanced statistics")
                    FeatureRow(icon: "target", text: "Custom reading goals")
                    FeatureRow(icon: "paintbrush.fill", text: "Themes & customization")
                    FeatureRow(icon: "cloud.fill", text: "Priority iCloud sync")
                }
                .padding(Theme.Spacing.lg)
                .cardStyle()

                Spacer()

                VStack(spacing: Theme.Spacing.sm) {
                    if let product = storeKit.products.first {
                        Button {
                            purchase(product)
                        } label: {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Get Pro - \(product.displayPrice)")
                                    .font(Theme.Typography.headline)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .primaryButton()
                        .disabled(isPurchasing)
                    } else {
                        ProgressView()
                    }

                    Button("Not now") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
            .padding(Theme.Spacing.xl)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }
        }
    }

    private func purchase(_ product: Product) {
        isPurchasing = true

        Task {
            do {
                try await storeKit.purchase(product)
                dismiss()
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 30)

            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.text)

            Spacer()
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Theme.Colors.primary)

                VStack(spacing: Theme.Spacing.xs) {
                    Text("Shlf")
                        .font(Theme.Typography.largeTitle)

                    Text("Your personal reading companion")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Text("Shlf helps you track your reading journey, build habits, and stay motivated with gamification. Whether you're reading physical books, ebooks, or listening to audiobooks, Shlf keeps you on track.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
            .padding(Theme.Spacing.xl)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataManagementView: View {
    var body: some View {
        Form {
            Section {
                Text("Export your reading data, clear cache, or reset the app.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Export") {
                Button("Export Reading Data") {
                    // TODO: Implement export
                }
            }

            Section("Danger Zone") {
                Button("Clear Cache") {
                    // TODO: Implement clear cache
                }

                Button("Reset App", role: .destructive) {
                    // TODO: Implement reset
                }
            }
        }
        .navigationTitle("Data Management")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

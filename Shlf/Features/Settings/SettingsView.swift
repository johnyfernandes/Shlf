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

                Section("Customization") {
                    NavigationLink {
                        HomeCardSettingsView(profile: profile)
                    } label: {
                        Label("Home Page Cards", systemImage: "square.grid.3x3")
                    }

                    NavigationLink {
                        ReadingPreferencesView(profile: profile)
                    } label: {
                        Label("Reading Preferences", systemImage: "book")
                    }

                    NavigationLink {
                        BookDetailCustomizationView(profile: profile)
                    } label: {
                        Label("Customize Book Details", systemImage: "slider.horizontal.3")
                    }
                }

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

struct ReadingPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section {
                Text("Customize how you track your reading progress")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Progress Tracking Mode") {
                Picker("Tracking Style", selection: $profile.useProgressSlider) {
                    Label("Stepper", systemImage: "plus.forwardslash.minus")
                        .tag(false)
                    Label("Slider", systemImage: "slider.horizontal.3")
                        .tag(true)
                }
                .pickerStyle(.inline)
                .onChange(of: profile.useProgressSlider) { oldValue, newValue in
                    try? modelContext.save()
                }

                Text(profile.useProgressSlider ?
                    "Drag the slider to quickly jump to any page" :
                    "Use +/- buttons to increment page by page")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            if profile.useProgressSlider {
                Section("Slider Options") {
                    Toggle(isOn: $profile.showSliderButtons) {
                        Label("Show +/- Buttons", systemImage: "plus.forwardslash.minus")
                    }
                    .onChange(of: profile.showSliderButtons) { oldValue, newValue in
                        try? modelContext.save()
                    }

                    Text("Add increment/decrement buttons alongside the slider for quick adjustments")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }

            if !profile.useProgressSlider || profile.showSliderButtons {
                Section("Quick Progress Increment") {
                    Picker("Pages per tap", selection: $profile.pageIncrementAmount) {
                        Text("1 page").tag(1)
                        Text("5 pages").tag(5)
                        Text("10 pages").tag(10)
                        Text("25 pages").tag(25)
                    }
                    .pickerStyle(.inline)

                    Text("When using +/- buttons, this is how many pages to add or remove with each tap")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
            }
        }
        .navigationTitle("Reading Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BookDetailCustomizationView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Form {
            Section {
                Text("Choose which sections to show on book detail pages")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Sections") {
                Toggle(isOn: $profile.showDescription) {
                    Label("Description", systemImage: "text.alignleft")
                }

                Toggle(isOn: $profile.showMetadata) {
                    Label("Details", systemImage: "info.circle")
                }

                Toggle(isOn: $profile.showSubjects) {
                    Label("Genres & Topics", systemImage: "tag")
                }

                Toggle(isOn: $profile.showReadingHistory) {
                    Label("Reading History", systemImage: "clock")
                }

                Toggle(isOn: $profile.showNotes) {
                    Label("Notes", systemImage: "note.text")
                }
            }

            if profile.showMetadata {
                Section("Details Fields") {
                    Toggle(isOn: $profile.showPublisher) {
                        Label("Publisher", systemImage: "building.2")
                    }

                    Toggle(isOn: $profile.showPublishedDate) {
                        Label("Published Date", systemImage: "calendar")
                    }

                    Toggle(isOn: $profile.showLanguage) {
                        Label("Language", systemImage: "globe")
                    }

                    Toggle(isOn: $profile.showISBN) {
                        Label("ISBN", systemImage: "barcode")
                    }

                    Toggle(isOn: $profile.showReadingTime) {
                        Label("Reading Time", systemImage: "clock")
                    }
                }
            }

            Section {
                Button("Reset to Defaults") {
                    profile.showDescription = true
                    profile.showMetadata = true
                    profile.showSubjects = true
                    profile.showReadingHistory = true
                    profile.showNotes = true
                    profile.showPublisher = true
                    profile.showPublishedDate = true
                    profile.showLanguage = true
                    profile.showISBN = true
                    profile.showReadingTime = true
                }
            }
        }
        .navigationTitle("Customize Book Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DataManagementView: View {
    @State private var showClearCacheAlert = false
    @State private var isClearing = false

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

            Section("Cache") {
                Button("Clear Image Cache") {
                    showClearCacheAlert = true
                }
                .disabled(isClearing)

                if isClearing {
                    HStack {
                        ProgressView()
                        Text("Clearing cache...")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }

            Section("Danger Zone") {
                Button("Reset App", role: .destructive) {
                    // TODO: Implement reset
                }
            }
        }
        .navigationTitle("Data Management")
        .alert("Clear Image Cache?", isPresented: $showClearCacheAlert) {
            Button("Clear", role: .destructive) {
                clearCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached book cover images. They will be downloaded again when needed.")
        }
    }

    private func clearCache() {
        isClearing = true
        Task {
            await ImageCacheManager.shared.clearCache()
            await MainActor.run {
                isClearing = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

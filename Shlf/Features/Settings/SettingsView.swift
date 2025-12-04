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

        // CRITICAL: Check again after fetching to prevent race condition
        // Another thread might have created profile between @Query and here
        let descriptor = FetchDescriptor<UserProfile>()
        if let existingAfterFetch = try? modelContext.fetch(descriptor).first {
            return existingAfterFetch
        }

        // Now safe to create
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save() // Save immediately to prevent other threads from creating
        return new
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section("Customization") {
                    NavigationLink {
                        ThemeColorSettingsView(profile: profile)
                    } label: {
                        Label {
                            Text("Theme Color")
                        } icon: {
                            Image(systemName: "paintbrush.fill")
                                .foregroundStyle(profile.themeColor.gradient)
                        }
                    }

                    NavigationLink {
                        HomeCardSettingsView(profile: profile)
                    } label: {
                        Label("Home Screen", systemImage: "square.grid.3x3")
                    }

                    NavigationLink {
                        ReadingPreferencesView(profile: profile)
                    } label: {
                        Label("Reading Progress", systemImage: "book")
                    }

                    NavigationLink {
                        SessionSettingsView(profile: profile)
                    } label: {
                        Label("Sessions", systemImage: "timer")
                    }

                    NavigationLink {
                        BookDetailCustomizationView(profile: profile)
                    } label: {
                        Label("Book Details", systemImage: "slider.horizontal.3")
                    }
                }

                Section("Apple Watch") {
                    NavigationLink {
                        WatchSettingsView()
                    } label: {
                        Label("Apple Watch", systemImage: "applewatch")
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
                        Label("About", systemImage: "info.circle")
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
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
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

                // Sync Pro status on launch (StoreKit is source of truth)
                if profile.isProUser != storeKit.isProUser {
                    profile.isProUser = storeKit.isProUser
                    try? modelContext.save()
                }
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

                        // CRITICAL: Sync Pro status - StoreKit is source of truth
                        profile.isProUser = storeKit.isProUser
                        try? modelContext.save()
                    }
                }
            }
        }
    }

}

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
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
                .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

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
                        .primaryButton(color: themeColor.color)
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

struct AboutView: View {
    @Environment(\.themeColor) private var themeColor
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(themeColor.color)

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
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @State private var showSaveError = false
    @State private var saveErrorMessage = ""

    var body: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background
            LinearGradient(
                colors: [
                    themeColor.color.opacity(0.12),
                    themeColor.color.opacity(0.04),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("About")
                                .font(.headline)
                        }

                        Text("Customize how you track your reading progress")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Progress Tracking Mode
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: profile.useProgressSlider ? "slider.horizontal.3" : "plus.forwardslash.minus")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 16)

                            Text("Tracking Style")
                                .font(.headline)
                        }

                        VStack(spacing: 12) {
                            // Stepper Option
                            Button {
                                withAnimation {
                                    profile.useProgressSlider = false
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                                        showSaveError = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.forwardslash.minus")
                                        .font(.title3)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Stepper")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text("Use +/- buttons to increment page by page")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if !profile.useProgressSlider {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(themeColor.color)
                                    }
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(profile.useProgressSlider ? .clear : themeColor.color, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)

                            // Slider Option
                            Button {
                                withAnimation {
                                    profile.useProgressSlider = true
                                    do {
                                        try modelContext.save()
                                    } catch {
                                        saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                                        showSaveError = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.title3)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Slider")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text("Drag the slider to quickly jump to any page")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if profile.useProgressSlider {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(themeColor.color)
                                    }
                                }
                                .padding(12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(profile.useProgressSlider ? themeColor.color : .clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // Slider Options
                    if profile.useProgressSlider {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Slider Options")
                                    .font(.headline)
                            }

                            Toggle(isOn: $profile.showSliderButtons) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Show +/- Buttons")
                                        .font(.subheadline.weight(.medium))

                                    Text("Add increment/decrement buttons alongside the slider")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tint(themeColor.color)
                            .onChange(of: profile.showSliderButtons) { oldValue, newValue in
                                do {
                                    try modelContext.save()
                                } catch {
                                    saveErrorMessage = "Failed to save: \(error.localizedDescription)"
                                    showSaveError = true
                                    profile.showSliderButtons = oldValue
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // Quick Progress Increment
                    if !profile.useProgressSlider || profile.showSliderButtons {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Image(systemName: "number.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(themeColor.color)
                                    .frame(width: 16)

                                Text("Pages per Tap")
                                    .font(.headline)
                            }

                            Text("When using +/- buttons, this is how many pages to add or remove with each tap")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            VStack(spacing: 10) {
                                ForEach([1, 5, 10, 25], id: \.self) { amount in
                                    Button {
                                        withAnimation {
                                            profile.pageIncrementAmount = amount
                                            try? modelContext.save()
                                        }
                                    } label: {
                                        HStack {
                                            Text("\(amount) page\(amount > 1 ? "s" : "")")
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            if profile.pageIncrementAmount == amount {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(themeColor.color)
                                            }
                                        }
                                        .padding(12)
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .strokeBorder(profile.pageIncrementAmount == amount ? themeColor.color : .clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Reading Progress")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save Error", isPresented: $showSaveError) {
            Button("OK") {}
        } message: {
            Text(saveErrorMessage)
        }
    }
}

struct BookDetailCustomizationView: View {
    @Environment(\.modelContext) private var modelContext
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
                    try? modelContext.save()
                }
            }
        }
        .navigationTitle("Book Details")
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

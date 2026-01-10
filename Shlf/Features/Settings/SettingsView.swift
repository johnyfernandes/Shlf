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
    @State private var isMigratingCloud = false
    @State private var showCloudRestartAlert = false
    @State private var cloudMigrationError: String?

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

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Dynamic gradient background
                LinearGradient(
                    colors: [
                        profile.themeColor.color.opacity(0.08),
                        profile.themeColor.color.opacity(0.02),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Form {
                    proSection

                    Section("Customization") {
                        if isProUser {
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
                        } else {
                            Button {
                                showUpgradeSheet = true
                            } label: {
                                Label {
                                    Text("Theme Color")
                                } icon: {
                                    Image(systemName: "paintbrush.fill")
                                        .foregroundStyle(profile.themeColor.gradient)
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        if isProUser {
                            NavigationLink {
                                HomeCardSettingsView(profile: profile)
                            } label: {
                                Label("Home Screen", systemImage: "square.grid.3x3")
                            }
                        } else {
                            Button {
                                showUpgradeSheet = true
                            } label: {
                                Label("Home Screen", systemImage: "square.grid.3x3")
                            }
                            .buttonStyle(.plain)
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

                        if isProUser {
                            NavigationLink {
                                BookDetailCustomizationView(profile: profile)
                            } label: {
                                Label("Book Details", systemImage: "slider.horizontal.3")
                            }
                        } else {
                            Button {
                                showUpgradeSheet = true
                            } label: {
                                Label("Book Details", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(.plain)
                        }

                        if isProUser {
                            NavigationLink {
                                StatsSettingsView()
                            } label: {
                                Label("Stats", systemImage: "chart.xyaxis.line")
                            }
                        } else {
                            Button {
                                showUpgradeSheet = true
                            } label: {
                                Label("Stats", systemImage: "chart.xyaxis.line")
                            }
                            .buttonStyle(.plain)
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
                        set: { handleCloudSyncToggle($0) }
                    ))
                    .disabled(!isProUser || isMigratingCloud)

                    if !isProUser {
                        Label("Available with Shlf Pro", systemImage: "lock.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    } else if profile.cloudSyncEnabled {
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
            .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .overlay {
                if isMigratingCloud {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()

                        ProgressView("Preparing iCloud Sync...")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradeView()
            }
            .alert("Restore Complete", isPresented: $showRestoreAlert) {
                Button("OK") {}
            } message: {
                Text("Your purchases have been restored.")
            }
            .alert("Restart Required", isPresented: $showCloudRestartAlert) {
                Button("Restart Now", role: .destructive) {
                    exit(0)
                }
                Button("Later") {}
            } message: {
                Text("iCloud Sync will finish switching after you restart the app.")
            }
            .alert("iCloud Sync Error", isPresented: Binding(
                get: { cloudMigrationError != nil },
                set: { _ in cloudMigrationError = nil }
            )) {
                Button("OK") {}
            } message: {
                Text(cloudMigrationError ?? "Unknown error.")
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

    private func handleCloudSyncToggle(_ isEnabled: Bool) {
        guard isProUser else {
            showUpgradeSheet = true
            return
        }

        guard profile.cloudSyncEnabled != isEnabled else { return }

        profile.cloudSyncEnabled = isEnabled
        try? modelContext.save()

        isMigratingCloud = true
        let targetMode: SwiftDataConfig.StorageMode = isEnabled ? .cloud : .local

        Task { @MainActor in
            do {
                try CloudSyncMigrator.migrate(modelContext: modelContext, to: targetMode)
                SwiftDataConfig.setStorageMode(targetMode)
                showCloudRestartAlert = true
            } catch {
                profile.cloudSyncEnabled.toggle()
                try? modelContext.save()
                cloudMigrationError = error.localizedDescription
            }
            isMigratingCloud = false
        }
    }

    private var proSection: some View {
        Section {
            if isProUser {
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
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
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
            .task {
                await storeKit.loadProducts()
            }
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

//
//  SettingsView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import StoreKit
import UIKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Bindable var profile: UserProfile

    @State private var storeKit = StoreKitService.shared
    @State private var showUpgradeSheet = false
    @State private var showRestoreAlert = false
    @State private var isMigratingCloud = false
    @State private var showCloudRestartAlert = false
    @State private var cloudMigrationError: String?
    @State private var cloudStatus: CloudDataStatus = .checking
    @State private var showCloudChoiceDialog = false

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    var body: some View {
        NavigationStack {
            Form {
                    proSection

                    Section("Appearance") {
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
                            AppIconSettingsView(profile: profile)
                        } label: {
                            Label("App Icon", systemImage: "app")
                        }
                    }

                    Section("Reading") {
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
                            StreakSettingsView(profile: profile)
                        } label: {
                            Label("Streaks", systemImage: "flame.fill")
                        }
                    }

                    Section("Library") {
                        NavigationLink {
                            HomeCardSettingsView(profile: profile)
                        } label: {
                            Label("Home Screen", systemImage: "square.grid.3x3")
                        }

                        NavigationLink {
                            BookDetailCustomizationView(profile: profile)
                        } label: {
                            Label("Book Details", systemImage: "slider.horizontal.3")
                        }

                        NavigationLink {
                            SubjectsSettingsView(profile: profile)
                        } label: {
                            Label("Subjects", systemImage: "tag.fill")
                        }
                    }

                    Section("Stats") {
                        NavigationLink {
                            BookStatsSettingsView(profile: profile)
                        } label: {
                            Label("Book Stats", systemImage: "chart.bar.xaxis")
                        }

                        NavigationLink {
                            StatsSettingsView()
                        } label: {
                            Label("Stats", systemImage: "chart.xyaxis.line")
                        }
                    }

                    Section("Sync & Integrations") {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Toggle("iCloud Sync", isOn: Binding(
                                get: { profile.cloudSyncEnabled },
                                set: { handleCloudSyncToggle($0) }
                            ))
                            .disabled(!isProUser || isMigratingCloud)
                            .confirmationDialog("Use iCloud Data?", isPresented: $showCloudChoiceDialog, titleVisibility: .visible) {
                                Button("Use iCloud Data") {
                                    enableCloudUsingRemoteData()
                                }
                                Button("Replace iCloud with This iPhone", role: .destructive) {
                                    migrateLocalToCloud()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text(cloudChoiceMessage)
                            }

                            cloudStatusInline
                        }

                        NavigationLink {
                            GoodreadsImportView(profile: profile)
                        } label: {
                            Label("Goodreads", systemImage: "books.vertical")
                        }

                        NavigationLink {
                            KindleImportView(profile: profile)
                        } label: {
                            Label("Kindle", systemImage: "book.closed")
                        }
                    }

                    Section("Devices") {
                        NavigationLink {
                            WatchSettingsView()
                        } label: {
                            Label("Apple Watch", systemImage: "applewatch")
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

                #if DEBUG
                Section("Developer") {
                    NavigationLink {
                        DeveloperSettingsView()
                    } label: {
                        Label("Developer", systemImage: "hammer.fill")
                    }
                }
                #endif

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
            }
            .labelStyle(SettingsLabelStyle())
            .tint(profile.themeColor.color)
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
                PaywallView()
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
                await refreshCloudStatus()

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
            profile.cloudSyncEnabled = false
            try? modelContext.save()
            return
        }

        guard profile.cloudSyncEnabled != isEnabled else { return }

        if isEnabled {
            requestEnableCloud()
        } else {
            disableCloudSync()
        }
    }

    @MainActor
    private func refreshCloudStatus() async {
        guard isProUser else {
            cloudStatus = .unknown
            return
        }

        cloudStatus = .checking
        do {
            let snapshot = try CloudSyncMigrator.fetchCloudSnapshot()
            if snapshot.hasData {
                cloudStatus = .available(snapshot)
            } else {
                cloudStatus = .empty
            }
        } catch {
            cloudStatus = .error(error.localizedDescription)
        }
    }

    private func requestEnableCloud() {
        isMigratingCloud = true
        Task { @MainActor in
            await refreshCloudStatus()
            isMigratingCloud = false

            switch cloudStatus {
            case .available(let snapshot):
                showCloudChoiceDialog = true
            case .empty:
                migrateLocalToCloud()
            case .error(let message):
                cloudMigrationError = message
            case .checking, .unknown:
                cloudMigrationError = "Unable to check iCloud status right now."
            }
        }
    }

    private func migrateLocalToCloud() {
        guard !isMigratingCloud else { return }
        profile.cloudSyncEnabled = true
        try? modelContext.save()

        isMigratingCloud = true
        Task { @MainActor in
            do {
                try CloudSyncMigrator.migrate(modelContext: modelContext, to: .cloud)
                SwiftDataConfig.setStorageMode(.cloud)
                showCloudRestartAlert = true
            } catch {
                profile.cloudSyncEnabled = false
                try? modelContext.save()
                cloudMigrationError = error.localizedDescription
            }
            isMigratingCloud = false
        }
    }

    private func enableCloudUsingRemoteData() {
        guard !isMigratingCloud else { return }
        profile.cloudSyncEnabled = true
        try? modelContext.save()

        isMigratingCloud = true
        Task { @MainActor in
            do {
                let cloudContainer = try SwiftDataConfig.createModelContainer(storageMode: .cloud)
                let cloudContext = cloudContainer.mainContext
                let descriptor = FetchDescriptor<UserProfile>()
                if let cloudProfile = try cloudContext.fetch(descriptor).first {
                    cloudProfile.cloudSyncEnabled = true
                } else {
                    let newProfile = UserProfile()
                    newProfile.cloudSyncEnabled = true
                    cloudContext.insert(newProfile)
                }
                try cloudContext.save()

                SwiftDataConfig.setStorageMode(.cloud)
                showCloudRestartAlert = true
            } catch {
                profile.cloudSyncEnabled = false
                try? modelContext.save()
                cloudMigrationError = error.localizedDescription
            }
            isMigratingCloud = false
        }
    }

    private func disableCloudSync() {
        guard !isMigratingCloud else { return }
        profile.cloudSyncEnabled = false
        try? modelContext.save()

        isMigratingCloud = true
        Task { @MainActor in
            do {
                try CloudSyncMigrator.migrate(modelContext: modelContext, to: .local)
                SwiftDataConfig.setStorageMode(.local)
                showCloudRestartAlert = true
            } catch {
                profile.cloudSyncEnabled = true
                try? modelContext.save()
                cloudMigrationError = error.localizedDescription
            }
            isMigratingCloud = false
        }
    }

    private var cloudStatusInline: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            if !isProUser {
                Text("Available with Shlf Pro")
            } else {
                switch cloudStatus {
                case .checking:
                    HStack(spacing: Theme.Spacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking iCloud data...")
                    }
                case .available(let snapshot):
                    Text(profile.cloudSyncEnabled ? "Sync is on" : "iCloud data found")
                        .foregroundStyle(Theme.Colors.success)
                    if let lastActivity = snapshot.lastActivity {
                    Text("Last activity") + Text(verbatim: " ") + Text(verbatim: formatDate(lastActivity))
                    }
                case .empty:
                    Text("No iCloud data yet")
                    Text("Your data will upload from this iPhone.")
                case .error:
                    Text("Unable to check iCloud data")
                        .foregroundStyle(Theme.Colors.warning)
                case .unknown:
                    EmptyView()
                }
            }
        }
        .font(.footnote)
        .foregroundStyle(Theme.Colors.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cloudChoiceMessage: String {
        if case .available(let snapshot) = cloudStatus {
            if let lastActivity = snapshot.lastActivity {
                return "We found iCloud data from \(formatDate(lastActivity)). Choose which data to keep."
            }
            return "We found iCloud data. Choose which data to keep."
        }
        return "Choose which data to keep."
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
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

private enum CloudDataStatus {
    case unknown
    case checking
    case available(CloudSyncMigrator.CloudSnapshot)
    case empty
    case error(String)
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

                VStack(spacing: Theme.Spacing.sm) {
                    Link(destination: URL(string: "https://shlf.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }

                    Link(destination: URL(string: "https://shlf.app/support")!) {
                        Label("Support", systemImage: "questionmark.circle")
                    }

                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        Label("EULA", systemImage: "doc.text")
                    }
                }
                .font(Theme.Typography.body)
                .foregroundStyle(themeColor.color)
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
                                            Text(verbatim: "\(amount)") + Text(verbatim: " ") + Text(amount == 1 ? "page" : "pages")
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
        .withDynamicTheme(profile.themeColor)
    }
}

private struct SettingsLabelStyle: LabelStyle {
    @Environment(\.themeColor) private var themeColor

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .foregroundStyle(themeColor.color)
                .frame(width: 18, alignment: .center)
            configuration.title
                .foregroundStyle(.primary)
        }
    }
}

struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showClearCacheAlert = false
    @State private var isClearing = false
    @State private var isExporting = false
    @State private var exportErrorMessage = ""
    @State private var showExportError = false
    @State private var showResetAlert = false
    @State private var isResetting = false
    @State private var resetErrorMessage = ""
    @State private var showResetError = false

    var body: some View {
        Form {
            Section {
                Text("Export your reading data, clear cache, or reset the app.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Section("Export") {
                Button("Export Reading Data") {
                    exportReadingData()
                }
                .disabled(isExporting || isResetting)

                if isExporting {
                    HStack {
                        ProgressView()
                        Text("Preparing export...")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
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
                    showResetAlert = true
                }
                .disabled(isExporting || isResetting)

                if isResetting {
                    HStack {
                        ProgressView()
                        Text("Resetting data...")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
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
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text(exportErrorMessage)
        }
        .alert("Reset App?", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This will permanently delete your books, sessions, goals, quotes, and streak history from this device. If iCloud Sync is enabled, it also removes them from iCloud.")
        }
        .alert("Reset Error", isPresented: $showResetError) {
            Button("OK") {}
        } message: {
            Text(resetErrorMessage)
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

    private func exportReadingData() {
        isExporting = true

        Task { @MainActor in
            do {
                let url = try ReadingDataExporter.export(modelContext: modelContext)
                isExporting = false
                shareExportFile(url)
            } catch {
                exportErrorMessage = error.localizedDescription
                showExportError = true
                isExporting = false
            }
        }
    }

    private func shareExportFile(_ url: URL) {
        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    private func resetApp() {
        isResetting = true

        Task { @MainActor in
            await ReadingSessionActivityManager.shared.endActivity()
            do {
                try deleteAll(ActiveReadingSession.self)
                try deleteAll(ReadingSession.self)
                try deleteAll(BookPosition.self)
                try deleteAll(Quote.self)
                try deleteAll(ReadingGoal.self)
                try deleteAll(Achievement.self)
                try deleteAll(StreakEvent.self)
                try deleteAll(Book.self)
                try deleteAll(UserProfile.self)
                try modelContext.save()
                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                await ImageCacheManager.shared.clearCache()
                isResetting = false
            } catch {
                resetErrorMessage = error.localizedDescription
                showResetError = true
                isResetting = false
            }
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let items = try modelContext.fetch(FetchDescriptor<T>())
        items.forEach { modelContext.delete($0) }
    }
}

#Preview {
    SettingsView(profile: UserProfile())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

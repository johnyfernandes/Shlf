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
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    @Bindable var profile: UserProfile

    @State private var storeKit = StoreKitService.shared
    @State private var showUpgradeSheet = false
    @State private var showRestoreAlert = false
    @State private var isMigratingCloud = false
    @State private var showCloudRestartAlert = false
    @State private var cloudMigrationError: String?
    @State private var cloudStatus: CloudDataStatus = .checking
    @State private var showCloudChoiceDialog = false
    @State private var showOnboarding = false
    @State private var showFocusInfo = false

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                appearanceSection
                readingSection
                syncSection
                notificationsSection
                librarySection
                statsSection
                devicesSection
                feedbackSection
                dataSection
                #if DEBUG
                developerSection
                #endif
                appSection
                versionSection
            }
            .alert("Notifications.StreakReminder.Focus.InfoTitle", isPresented: $showFocusInfo) {
                Button("Notifications.StreakReminder.Focus.InfoDismiss", role: .cancel) {}
            } message: {
                Text("Notifications.StreakReminder.Focus.InfoMessage")
            }
            .labelStyle(SettingsLabelStyle())
            .tint(profile.themeColor.color)
            .navigationTitle(Text(verbatim: localized("Settings.Title", locale: locale)))
            .overlay {
                if isMigratingCloud {
                    ZStack {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()

                        ProgressView {
                            Text(verbatim: localized("Settings.PreparingICloudSync", locale: locale))
                        }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .sheet(isPresented: $showUpgradeSheet) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView(isPresented: $showOnboarding)
            }
            .alert(Text(verbatim: localized("Settings.RestoreComplete", locale: locale)), isPresented: $showRestoreAlert) {
                Button {
                } label: {
                    Text(verbatim: localized("Common.OK", locale: locale))
                }
            } message: {
                Text(verbatim: localized("Settings.RestoreComplete.Message", locale: locale))
            }
            .alert(Text(verbatim: localized("Settings.RestartRequired", locale: locale)), isPresented: $showCloudRestartAlert) {
                Button(role: .destructive) {
                    exit(0)
                } label: {
                    Text(verbatim: localized("Settings.RestartNow", locale: locale))
                }
                Button {
                } label: {
                    Text(verbatim: localized("Settings.Later", locale: locale))
                }
            } message: {
                Text(verbatim: localized("Settings.RestartRequired.Message", locale: locale))
            }
            .alert(Text(verbatim: localized("Settings.iCloudSyncError", locale: locale)), isPresented: Binding(
                get: { cloudMigrationError != nil },
                set: { _ in cloudMigrationError = nil }
            )) {
                Button {
                } label: {
                    Text(verbatim: localized("Common.OK", locale: locale))
                }
            } message: {
                Text(cloudMigrationError ?? localized("Settings.UnknownError", locale: locale))
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

    @ViewBuilder
    private var appearanceSection: some View {
        Section {
            NavigationLink {
                ThemeColorSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.ThemeColor", locale: locale))
                } icon: {
                    Image(systemName: "paintbrush.fill")
                        .foregroundStyle(profile.themeColor.gradient)
                }
            }

            NavigationLink {
                AppIconSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.AppIcon", locale: locale))
                } icon: {
                    Image(systemName: "app")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Appearance", locale: locale))
        }
    }

    @ViewBuilder
    private var readingSection: some View {
        Section {
            NavigationLink {
                ReadingPreferencesView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.ReadingProgress", locale: locale))
                } icon: {
                    Image(systemName: "book")
                }
            }

            NavigationLink {
                SessionSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Sessions", locale: locale))
                } icon: {
                    Image(systemName: "timer")
                }
            }

            NavigationLink {
                StreakSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Streaks", locale: locale))
                } icon: {
                    Image(systemName: "flame.fill")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Reading", locale: locale))
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        Section {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Toggle(isOn: Binding(
                    get: { profile.cloudSyncEnabled },
                    set: { handleCloudSyncToggle($0) }
                )) {
                    Text(verbatim: localized("Settings.iCloudSync", locale: locale))
                }
                .disabled(!isProUser || isMigratingCloud)
                .confirmationDialog(Text(verbatim: localized("Settings.iCloud.ChoiceTitle", locale: locale)), isPresented: $showCloudChoiceDialog, titleVisibility: .visible) {
                    Button {
                        enableCloudUsingRemoteData()
                    } label: {
                        Text(verbatim: localized("Settings.iCloud.UseData", locale: locale))
                    }
                    Button(role: .destructive) {
                        migrateLocalToCloud()
                    } label: {
                        Text(verbatim: localized("Settings.iCloud.ReplaceWithDevice", locale: locale))
                    }
                    Button(role: .cancel) {
                    } label: {
                        Text(verbatim: localized("Common.Cancel", locale: locale))
                    }
                } message: {
                    Text(cloudChoiceMessage)
                }

                cloudStatusInline
            }

            NavigationLink {
                GoodreadsImportView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Goodreads", locale: locale))
                } icon: {
                    Image(systemName: "books.vertical")
                }
            }

            NavigationLink {
                KindleImportView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Kindle", locale: locale))
                } icon: {
                    Image(systemName: "book.closed")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.SyncIntegrations", locale: locale))
        }
    }

    @ViewBuilder
    private var librarySection: some View {
        Section {
            NavigationLink {
                HomeCardSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.HomeScreen", locale: locale))
                } icon: {
                    Image(systemName: "square.grid.3x3")
                }
            }

            NavigationLink {
                BookDetailCustomizationView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.BookDetails", locale: locale))
                } icon: {
                    Image(systemName: "slider.horizontal.3")
                }
            }

            NavigationLink {
                SubjectsSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Subjects", locale: locale))
                } icon: {
                    Image(systemName: "tag.fill")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Library", locale: locale))
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        Section {
            NavigationLink {
                BookStatsSettingsView(profile: profile)
            } label: {
                Label {
                    Text(verbatim: localized("Settings.BookStats", locale: locale))
                } icon: {
                    Image(systemName: "chart.bar.xaxis")
                }
            }

            NavigationLink {
                StatsSettingsView()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Stats", locale: locale))
                } icon: {
                    Image(systemName: "chart.xyaxis.line")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Stats", locale: locale))
        }
    }

    @ViewBuilder
    private var devicesSection: some View {
        Section {
            NavigationLink {
                WatchSettingsView()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.AppleWatch", locale: locale))
                } icon: {
                    Image(systemName: "applewatch")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Devices", locale: locale))
        }
    }

    @ViewBuilder
    private var feedbackSection: some View {
        Section {
            NavigationLink {
                FeedbackView()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.SendFeedback", locale: locale))
                } icon: {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                }
            }

            NavigationLink {
                FeatureRequestsView()
            } label: {
                Label {
                    Text(verbatim: localized("FeatureRequests.Title", locale: locale))
                } icon: {
                    Image(systemName: "lightbulb")
                }
            }
        } header: {
            Text(verbatim: localized("Feedback.Title", locale: locale))
        }
    }

    @ViewBuilder
    private var dataSection: some View {
        Section {
            NavigationLink {
                DataManagementView()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.DataManagement", locale: locale))
                } icon: {
                    Image(systemName: "folder")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Data", locale: locale))
        }
    }

    #if DEBUG
    @ViewBuilder
    private var developerSection: some View {
        Section {
            NavigationLink {
                DeveloperSettingsView()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Developer", locale: locale))
                } icon: {
                    Image(systemName: "hammer.fill")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.Developer", locale: locale))
        }
    }
    #endif

    @ViewBuilder
    private var appSection: some View {
        Section {
            NavigationLink {
                AboutView()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.About", locale: locale))
                } icon: {
                    Image(systemName: "info.circle")
                }
            }

            Button {
                showOnboarding = true
            } label: {
                Label {
                    Text(verbatim: localized("Settings.Onboarding", locale: locale))
                } icon: {
                    Image(systemName: "sparkles")
                }
            }

            if let url = URL(string: "https://shlf.app") {
                Link(destination: url) {
                    Label {
                        Text(verbatim: localized("Settings.VisitWebsite", locale: locale))
                    } icon: {
                        Image(systemName: "safari")
                    }
                }
            } else {
                Label {
                    Text(verbatim: localized("Settings.VisitWebsite", locale: locale))
                } icon: {
                    Image(systemName: "safari")
                }
                .foregroundStyle(Theme.Colors.secondaryText)
            }

            Button {
                requestReview()
            } label: {
                Label {
                    Text(verbatim: localized("Settings.RateShlf", locale: locale))
                } icon: {
                    Image(systemName: "star")
                }
            }
        } header: {
            Text(verbatim: localized("Settings.AppSection", locale: locale))
        }
    }

    @ViewBuilder
    private var versionSection: some View {
        Section {
            HStack {
                Text(verbatim: localized("Settings.Version", locale: locale))
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .foregroundStyle(Theme.Colors.secondaryText)
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
            case .available:
                showCloudChoiceDialog = true
            case .empty:
                migrateLocalToCloud()
            case .error(let message):
                cloudMigrationError = message
            case .checking, .unknown:
                cloudMigrationError = localized("Settings.UnableToCheckICloudStatus", locale: locale)
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
                Text(verbatim: localized("Settings.AvailableWithPro", locale: locale))
            } else {
                switch cloudStatus {
                case .checking:
                    HStack(spacing: Theme.Spacing.xs) {
                        ProgressView()
                            .controlSize(.small)
                        Text(verbatim: localized("Settings.CheckingICloudData", locale: locale))
                    }
                case .available(let snapshot):
                    Text(profile.cloudSyncEnabled
                         ? localized("Settings.SyncIsOn", locale: locale)
                         : localized("Settings.iCloudDataFound", locale: locale))
                        .foregroundStyle(Theme.Colors.success)
                    if let lastActivity = snapshot.lastActivity {
                        Text(
                            String.localizedStringWithFormat(
                                localized("Settings.LastActivityFormat", locale: locale),
                                formatDate(lastActivity)
                            )
                        )
                    }
                case .empty:
                    Text(verbatim: localized("Settings.NoICloudDataYet", locale: locale))
                    Text(verbatim: localized("Settings.DataWillUploadFromDevice", locale: locale))
                case .error:
                    Text(verbatim: localized("Settings.UnableToCheckICloudData", locale: locale))
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
                return String(
                    format: localized("Settings.ChoiceMessageWithDate", locale: locale),
                    locale: locale,
                    arguments: [formatDate(lastActivity)]
                )
            }
            return localized("Settings.ChoiceMessageFound", locale: locale)
        }
        return localized("Settings.ChoiceMessageDefault", locale: locale)
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private var proSection: some View {
        Section {
            if isProUser {
                HStack {
                    AppIconBadgeView(
                        iconImage: currentAppIconImage,
                        badgeColor: currentAppIconAccent.color,
                        badgeIsLight: currentAppIconAccent.isLight,
                        showBadge: true,
                        fallbackTint: themeColor.color
                    )
                    .padding(.trailing, Theme.Spacing.xs)

                    Text(verbatim: localized("Settings.ProTitle", locale: locale))
                        .font(Theme.Typography.headline)

                    Spacer()

                    Text(verbatim: localized("Settings.ProActive", locale: locale))
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.success)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Theme.Colors.secondaryBackground.opacity(0.6))
                        )
                }
            } else {
                Button {
                    showUpgradeSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            HStack {
                                AppIconBadgeView(
                                    iconImage: currentAppIconImage,
                                    badgeColor: currentAppIconAccent.color,
                                    badgeIsLight: currentAppIconAccent.isLight,
                                    showBadge: false,
                                    fallbackTint: themeColor.color
                                )

                                Text(verbatim: localized("Settings.UpgradeToPro", locale: locale))
                                    .font(Theme.Typography.headline)
                            }

                            Text(verbatim: localized("Settings.UnlimitedBooksFeatures", locale: locale))
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }

                Button {
                    Task {
                        await storeKit.restorePurchases()
                        showRestoreAlert = true

                        // CRITICAL: Sync Pro status - StoreKit is source of truth
                        profile.isProUser = storeKit.isProUser
                        try? modelContext.save()
                    }
                } label: {
                    Text(verbatim: localized("Settings.RestorePurchases", locale: locale))
                }
            }
        }
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

}

private enum CloudDataStatus {
    case unknown
    case checking
    case available(CloudSyncMigrator.CloudSnapshot)
    case empty
    case error(String)
}

private struct AppIconBadgeView: View {
    @Environment(\.themeColor) private var themeColor
    let iconImage: UIImage?
    let badgeColor: Color
    let badgeIsLight: Bool
    let showBadge: Bool
    let fallbackTint: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let iconImage {
                Image(uiImage: iconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(fallbackTint.opacity(0.2))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(fallbackTint)
                    )
            }

            if showBadge {
                Text("Common.Pro")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(badgeIsLight ? Color.black.opacity(0.85) : .white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        badgeColor.opacity(badgeIsLight ? 0.9 : 0.95),
                                        badgeColor.opacity(badgeIsLight ? 0.75 : 0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(badgeIsLight ? Color.black.opacity(0.2) : Color.white.opacity(0.6), lineWidth: 0.6)
                    )
                    .shadow(color: badgeColor.opacity(badgeIsLight ? 0.35 : 0.85), radius: 5, y: 2)
                    .shadow(color: badgeColor.opacity(badgeIsLight ? 0.25 : 0.75), radius: 7, y: 0)
                    .offset(x: 6, y: -6)
            }
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
                    Text("App.Name")
                        .font(Theme.Typography.largeTitle)

                    Text("Settings.About.Tagline")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Text("Settings.About.Description")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.sm) {
                    if let url = URL(string: "https://shlf.app/privacy") {
                        Link(destination: url) {
                            Label("Settings.About.PrivacyPolicy", systemImage: "hand.raised")
                        }
                    } else {
                        Label("Settings.About.PrivacyPolicy", systemImage: "hand.raised")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    if let url = URL(string: "https://shlf.app/support") {
                        Link(destination: url) {
                            Label("Settings.About.Support", systemImage: "questionmark.circle")
                        }
                    } else {
                        Label("Settings.About.Support", systemImage: "questionmark.circle")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }

                    if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                        Link(destination: url) {
                            Label("Settings.About.EULA", systemImage: "doc.text")
                        }
                    } else {
                        Label("Settings.About.EULA", systemImage: "doc.text")
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                }
                .font(Theme.Typography.body)
                .foregroundStyle(themeColor.color)
            }
            .padding(Theme.Spacing.xl)
        }
        .navigationTitle("Settings.About.Title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReadingPreferencesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
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

                            Text(localized("About", locale: locale))
                                .font(.headline)
                        }

                        Text(localized("Customize how you track your reading progress", locale: locale))
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
                                        Text(localized("Stepper", locale: locale))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text(localized("Use +/- buttons to increment page by page", locale: locale))
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
                                        Text(localized("Slider", locale: locale))
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.primary)

                                        Text(localized("Drag the slider to quickly jump to any page", locale: locale))
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

                            Text(localized("When using +/- buttons, this is how many pages to add or remove with each tap", locale: locale))
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
                                            Text("\(amount) \(amount == 1 ? String(localized: "page") : String(localized: "pages"))")
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
    @State private var showResetConfirmAlert = false
    @State private var isResetting = false
    @State private var resetErrorMessage = ""
    @State private var showResetError = false
    @State private var resetConfirmText = ""

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
            Button("Continue", role: .destructive) {
                resetConfirmText = ""
                showResetConfirmAlert = true
            }
        } message: {
            Text("This will permanently delete your books, sessions, goals, quotes, and streak history from this device. If iCloud Sync is enabled, it also removes them from iCloud.")
        }
        .alert("Settings.ResetConfirm.Title", isPresented: $showResetConfirmAlert) {
            TextField("Settings.ResetConfirm.Placeholder", text: $resetConfirmText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetApp()
            }
            .disabled(resetConfirmText != "RESET")
        } message: {
            Text("Settings.ResetConfirm.Message")
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
                resetTooltipPreferences()
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

    private func resetTooltipPreferences() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "progressEditTooltipDismissed")
        defaults.removeObject(forKey: "logSessionToPageTooltipDismissed")
    }
}

extension SettingsView {
    private var notificationsSection: some View {
        Section("Notifications.Section") {
            NavigationLink {
                NotificationsSettingsView(profile: profile)
            } label: {
                Label("Notifications.StreakReminder.Label", systemImage: "bell.badge.fill")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Toggle(isOn: Binding(
                    get: { profile.streakReminderRespectFocus },
                    set: { handleFocusRespectToggle($0) }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Notifications.StreakReminder.Focus.Title")
                                .font(.subheadline.weight(.medium))
                            Button {
                                showFocusInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Notifications.StreakReminder.Focus.Info")
                        }
                        Text("Notifications.StreakReminder.Focus.Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!profile.streakReminderEnabled)
                .opacity(profile.streakReminderEnabled ? 1 : 0.6)
            }
        }
    }

    private func handleFocusRespectToggle(_ isOn: Bool) {
        profile.streakReminderRespectFocus = isOn
        Task { @MainActor in
            await NotificationScheduler.shared.refreshSchedule(for: profile)
            try? modelContext.save()
        }
    }
}

#Preview {
    SettingsView(profile: UserProfile())
        .modelContainer(for: [UserProfile.self], inMemory: true)
}

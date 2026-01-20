//
//  KindleImportView.swift
//  Shlf
//
//  Kindle library import
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI
import SwiftData

struct KindleImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var profile: UserProfile
    @Query private var books: [Book]
    @AppStorage("kindle_is_connected") private var storedKindleConnected = false
    @AppStorage("kindle_force_disconnected") private var forceKindleDisconnected = false

    @StateObject private var coordinator = KindleImportCoordinator()
    @State private var showWebImport = false
    @State private var result: KindleImportResult?
    @State private var isImporting = false
    @State private var importProgressCurrent = 0
    @State private var importProgressTotal = 0
    @State private var importProgressTitle: String?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false
    @State private var showDisconnectAlert = false
    @State private var pulseConnected = false

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    private var showCoordinatorProgress: Bool {
        switch coordinator.phase {
        case .scanning:
            return true
        default:
            return false
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                    if showCoordinatorProgress {
                        coordinatorProgressCard
                    }
                    importSection
                    if isImporting || result != nil {
                        importStatusSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if !showWebImport {
                GoodreadsWebView(webView: coordinator.webView)
                    .frame(width: 1, height: 1)
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .navigationTitle("Kindle")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWebImport) {
            KindleWebImportView(coordinator: coordinator)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(LocalizedStringKey(errorMessage))
        }
        .alert("Disconnect Kindle", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                forceKindleDisconnected = true
                coordinator.disconnect()
                storedKindleConnected = false
            }
        } message: {
            Text("Disconnecting will remove the Kindle session from this device. You can reconnect anytime.")
        }
        .onAppear {
            Task {
                if !forceKindleDisconnected {
                    await coordinator.refreshConnectionStatus()
                } else {
                    coordinator.isConnected = false
                }
            }
        }
        .onChange(of: coordinator.isConnected) { _, isConnected in
            guard !forceKindleDisconnected else { return }
            storedKindleConnected = isConnected
            if isConnected {
                forceKindleDisconnected = false
            }
        }
        .onChange(of: coordinator.requiresLogin) { _, requiresLogin in
            if requiresLogin {
                forceKindleDisconnected = false
                storedKindleConnected = false
                showWebImport = true
            }
        }
        .onChange(of: coordinator.items) { _, items in
            guard !items.isEmpty else { return }
            startImport(with: items)
        }
        .onChange(of: coordinator.errorMessage) { _, message in
            guard let message else { return }
            errorMessage = message
            showError = true
        }
    }

    private var coordinatorProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                Text(coordinator.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Keep this screen open while we import.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var importSection: some View {
        let displayConnected = storedKindleConnected && !forceKindleDisconnected
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Import from Kindle")
                    .font(.headline)

                Spacer()

                connectionPill
            }

            Text("Sign in with your Amazon account and we'll import your Kindle library.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Kindle only provides your library list. Reading status and dates aren't available.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if displayConnected {
                    coordinator.start(syncOnly: true)
                } else {
                    forceKindleDisconnected = false
                    showWebImport = true
                }
            } label: {
                let primaryTitle: LocalizedStringKey = displayConnected ? "Sync now" : "Import from Kindle"
                Text(primaryTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeColor.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(showCoordinatorProgress || isImporting)

            if displayConnected {
                Button {
                    showDisconnectAlert = true
                } label: {
                    Text("Disconnect Kindle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var connectionPill: some View {
        let connected = storedKindleConnected && !forceKindleDisconnected
        return HStack(spacing: 6) {
            ZStack {
                if connected {
                    Circle()
                        .fill(Color.green.opacity(0.25))
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulseConnected ? 1.6 : 0.9)
                        .opacity(pulseConnected ? 0.0 : 1.0)
                }

                Circle()
                    .fill(connected ? Color.green : Color.secondary)
                    .frame(width: 7, height: 7)
            }
            let statusText: LocalizedStringKey = connected ? "Connected" : "Not Connected"
            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(connected ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((connected ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12)), in: Capsule())
        .onAppear {
            updatePulse(for: connected)
        }
        .onChange(of: storedKindleConnected) { _, newValue in
            updatePulse(for: connected)
        }
        .onChange(of: forceKindleDisconnected) { _, _ in
            updatePulse(for: connected)
        }
    }

    private func updatePulse(for connected: Bool) {
        guard connected else {
            pulseConnected = false
            return
        }

        pulseConnected = false
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseConnected = true
        }
    }

    private var importStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isImporting {
                importProgressView
            }

            if let result {
                Divider()

                Text("Import Complete")
                    .font(.headline)

                summaryRow(title: Text("Imported \(result.importedCount) books"))
                if result.skippedCount > 0 {
                    summaryRow(title: Text("Skipped \(result.skippedCount) rows"))
                }
                if result.reachedFreeLimit {
                    summaryRow(title: Text("Stopped at free limit"))

                    Button {
                        showUpgradeSheet = true
                    } label: {
                        Text("Upgrade to Pro")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(themeColor.color)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity((isImporting || result != nil) ? 1 : 0)
    }

    private var importProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let total = max(importProgressTotal, 1)
            let current = min(importProgressCurrent, total)
            ProgressView(value: Double(current), total: Double(total))
                .progressViewStyle(.linear)

                                    Text(
                                        String.localizedStringWithFormat(
                                            String(localized: "Importing %lld of %lld books"),
                                            current,
                                            total
                                        )
                                    )
                .font(.caption)
                .foregroundStyle(.secondary)

            if let title = importProgressTitle, !title.isEmpty {
                Text("Adding \(title)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(title: Text, value: Text? = nil) -> some View {
        HStack {
            title
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let value {
                value
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
            }
        }
    }

    private func startImport(with items: [KindleImportItem]) {
        guard !isImporting else { return }
        isImporting = true
        result = nil
        importProgressCurrent = 0
        importProgressTotal = items.count
        importProgressTitle = nil

        Task { @MainActor in
            do {
                let importResult = try await KindleImportService.import(
                    items: items,
                    modelContext: modelContext,
                    isProUser: isProUser,
                    progress: { progress in
                        importProgressCurrent = progress.current
                        importProgressTotal = progress.total
                        importProgressTitle = progress.title
                    }
                )
                result = importResult
                profile.syncSubjects(from: books)
                try? modelContext.save()

                WidgetDataExporter.exportSnapshot(modelContext: modelContext)
                if importResult.importedCount > 0 {
                    await WatchConnectivityManager.shared.syncBooksToWatch()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isImporting = false
            importProgressTitle = nil
        }
    }
}

#Preview {
    NavigationStack {
        KindleImportView(profile: UserProfile())
            .modelContainer(for: [UserProfile.self], inMemory: true)
    }
}
#endif

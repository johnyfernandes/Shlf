//
//  GoodreadsImportView.swift
//  Shlf
//
//  Goodreads CSV import
//

#if os(iOS) && !WIDGET_EXTENSION
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct GoodreadsImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @Bindable var profile: UserProfile
    @Query private var books: [Book]
    @AppStorage("goodreads_is_connected") private var storedGoodreadsConnected = false
    @AppStorage("goodreads_force_disconnected") private var forceGoodreadsDisconnected = false

    @StateObject private var coordinator = GoodreadsImportCoordinator()
    @State private var showWebImport = false
    @State private var showImporter = false
    @State private var selectedFileName: String?
    @State private var document: GoodreadsImportDocument?
    @State private var result: GoodreadsImportResult?
    @State private var isParsing = false
    @State private var isImporting = false
    @State private var isEnrichingDescriptions = false
    @State private var importProgressCurrent = 0
    @State private var importProgressTotal = 0
    @State private var importProgressTitle: String?
    @State private var descriptionProgressCurrent = 0
    @State private var descriptionProgressTotal = 0
    @State private var descriptionProgressTitle: String?
    @State private var pendingDocument: GoodreadsImportDocument?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false
    @State private var showDisconnectAlert = false
    @State private var pulseConnected = false

    @State private var options = GoodreadsImportOptions()

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
    }

    private var showCoordinatorProgress: Bool {
        switch coordinator.phase {
        case .exporting, .waitingForExport, .downloading:
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
                    automatedImportSection
                    manualImportSection
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
        .navigationTitle("Goodreads")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                loadCSV(from: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(LocalizedStringKey(errorMessage))
        }
        .sheet(isPresented: $showWebImport) {
            GoodreadsWebImportView(coordinator: coordinator)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
        .alert("Disconnect Goodreads", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                forceGoodreadsDisconnected = true
                coordinator.disconnect()
                storedGoodreadsConnected = false
            }
        } message: {
            Text("Disconnecting will remove the Goodreads session from this device. You can reconnect anytime.")
        }
        .onAppear {
            Task {
                if !forceGoodreadsDisconnected {
                    await refreshConnectionWithRetry()
                } else {
                    coordinator.isConnected = false
                }
            }
        }
        .onChange(of: coordinator.isConnected) { _, isConnected in
            guard !forceGoodreadsDisconnected else { return }
            storedGoodreadsConnected = isConnected
            if isConnected {
                forceGoodreadsDisconnected = false
            }
        }
        .onChange(of: coordinator.downloadedData) { _, data in
            guard let data else { return }
            handleCSVData(data, fileName: "goodreads_library_export.csv")
        }
        .onChange(of: coordinator.errorMessage) { _, message in
            guard let message else { return }
            errorMessage = message
            showError = true
        }
        .onChange(of: coordinator.requiresLogin) { _, requiresLogin in
            if requiresLogin {
                forceGoodreadsDisconnected = false
                storedGoodreadsConnected = false
                showWebImport = true
            }
        }
        .onChange(of: coordinator.phase) { _, newPhase in
            if case .finished = newPhase {
                Task { @MainActor in
                    await coordinator.refreshConnectionStatus()
                }
            }
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

    private var automatedImportSection: some View {
        let displayConnected = storedGoodreadsConnected && !forceGoodreadsDisconnected
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.doc")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Import from Goodreads")
                    .font(.headline)

                Spacer()

                connectionPill
            }

            Text("We'll import your library using Goodreads' official export. If Goodreads blocks it, you can upload the export CSV.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                if displayConnected {
                    coordinator.start(syncOnly: true)
                } else {
                    forceGoodreadsDisconnected = false
                    showWebImport = true
                }
            } label: {
                let isSyncing = showCoordinatorProgress || isParsing || isImporting
                let primaryTitle: LocalizedStringKey = displayConnected ? "Sync now" : "Import from Goodreads"
                HStack(spacing: 10) {
                    if isSyncing {
                        ProgressView()
                            .tint(themeColor.onColor(for: colorScheme))
                    }
                    Text(isSyncing ? "Syncing..." : primaryTitle)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(themeColor.onColor(for: colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeColor.color.opacity(isSyncing ? 0.6 : 1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(showCoordinatorProgress || isParsing || isImporting)

            if showCoordinatorProgress || isParsing || isImporting {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Syncing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if displayConnected {
                Button {
                    showDisconnectAlert = true
                } label: {
                    Text("Disconnect Goodreads")
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
        let connected = storedGoodreadsConnected && !forceGoodreadsDisconnected
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
        .onChange(of: storedGoodreadsConnected) { _, _ in
            updatePulse(for: connected)
        }
        .onChange(of: forceGoodreadsDisconnected) { _, _ in
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

    private func refreshConnectionWithRetry() async {
        await coordinator.refreshConnectionStatus()
        guard !coordinator.isConnected else { return }
        try? await Task.sleep(for: .milliseconds(650))
        await coordinator.refreshConnectionStatus()
    }

    private var manualImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Manual CSV upload")
                    .font(.headline)
            }

            Text("Goodreads -> My Books -> Export Library -> Download CSV -> Upload here")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showImporter = true
            } label: {
                Text("Upload CSV")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
            }
            .disabled(isParsing || isImporting)

            if let selectedFileName {
                Text(selectedFileName)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            if isParsing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(localized("Parsing CSV...", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var importStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isImporting {
                importProgressView
            }

            if isEnrichingDescriptions {
                descriptionProgressView
            }

            if let result {
                Divider()

                Text(localized("Import Complete", locale: locale))
                    .font(.headline)

                summaryRow(
                    title: Text(
                        String.localizedStringWithFormat(
                            localized("Imported %lld books", locale: locale),
                            result.importedCount
                        )
                    )
                )
                if result.updatedCount > 0 {
                    summaryRow(
                        title: Text(
                            String.localizedStringWithFormat(
                                localized("Updated %lld books", locale: locale),
                                result.updatedCount
                            )
                        )
                    )
                }
                if result.skippedCount > 0 {
                    summaryRow(
                        title: Text(
                            String.localizedStringWithFormat(
                                localized("Skipped %lld rows", locale: locale),
                                result.skippedCount
                            )
                        )
                    )
                }
                if result.createdSessions > 0 {
                    summaryRow(
                        title: Text(
                            String.localizedStringWithFormat(
                                localized("Created %lld imported sessions", locale: locale),
                                result.createdSessions
                            )
                        )
                    )
                }
                if result.reachedFreeLimit {
                    summaryRow(title: Text(localized("Stopped at free limit", locale: locale)))

                    Button {
                        showUpgradeSheet = true
                    } label: {
                        Text(localized("Upgrade to Pro", locale: locale))
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
                                            localized("Importing %lld of %lld books", locale: locale),
                                            current,
                                            total
                                        )
                                    )
                .font(.caption)
                .foregroundStyle(.secondary)

            if let title = importProgressTitle, !title.isEmpty {
                Text(
                    String.localizedStringWithFormat(
                        localized("Adding %@", locale: locale),
                        title
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var descriptionProgressView: some View {
        VStack(alignment: .leading, spacing: 8) {
            let total = max(descriptionProgressTotal, 1)
            let current = min(descriptionProgressCurrent, total)
            ProgressView(value: Double(current), total: Double(total))
                .progressViewStyle(.linear)

                                    Text(
                                        String.localizedStringWithFormat(
                                            localized("Fetching descriptions %lld of %lld", locale: locale),
                                            current,
                                            total
                                        )
                                    )
                .font(.caption)
                .foregroundStyle(.secondary)

            if let title = descriptionProgressTitle, !title.isEmpty {
                Text(
                    String.localizedStringWithFormat(
                        localized("Adding description for %@", locale: locale),
                        title
                    )
                )
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

    private func loadCSV(from url: URL) {
        isParsing = true
        selectedFileName = url.lastPathComponent
        document = nil
        result = nil

        Task {
            let access = url.startAccessingSecurityScopedResource()
            defer {
                if access {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                await MainActor.run {
                    handleCSVData(data, fileName: url.lastPathComponent)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isParsing = false
                }
            }
        }
    }

    private func handleCSVData(_ data: Data, fileName: String?) {
        isParsing = true
        selectedFileName = fileName
        document = nil
        result = nil
        pendingDocument = nil

        Task {
            do {
                let parsed = try GoodreadsImportService.parse(data: data)
                await MainActor.run {
                    document = parsed
                    isParsing = false
                    handleParsedDocument(parsed)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isParsing = false
                }
            }
        }
    }

    private func handleParsedDocument(_ parsed: GoodreadsImportDocument) {
        guard !isImporting else { return }

        pendingDocument = parsed
        startImport(preferGoodreadsData: false)
    }

    private func startImport(preferGoodreadsData: Bool) {
        guard let document = pendingDocument ?? document else { return }
        isImporting = true
        result = nil
        importProgressCurrent = 0
        importProgressTotal = document.rows.count
        importProgressTitle = nil
        isEnrichingDescriptions = false
        descriptionProgressCurrent = 0
        descriptionProgressTotal = 0
        descriptionProgressTitle = nil
        pendingDocument = document

        options.preferGoodreadsData = preferGoodreadsData

        Task { @MainActor in
            do {
                let importResult = try await GoodreadsImportService.import(
                    document: document,
                    options: options,
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
                if importResult.importedCount > 0 || importResult.updatedCount > 0 {
                    await WatchConnectivityManager.shared.syncBooksToWatch()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isImporting = false
            importProgressTitle = nil
            pendingDocument = nil

            if let importResult = result, !importResult.booksNeedingDescriptions.isEmpty {
                isEnrichingDescriptions = true
                descriptionProgressTotal = importResult.booksNeedingDescriptions.count
                descriptionProgressCurrent = 0
                descriptionProgressTitle = nil
                let booksToEnrich = importResult.booksNeedingDescriptions

                Task { @MainActor in
                    await GoodreadsImportService.enrichDescriptions(
                        books: booksToEnrich,
                        modelContext: modelContext
                    ) { current, total, title in
                        descriptionProgressCurrent = current
                        descriptionProgressTotal = total
                        descriptionProgressTitle = title
                    }
                    isEnrichingDescriptions = false
                    descriptionProgressTitle = nil
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        GoodreadsImportView(profile: UserProfile())
            .modelContainer(for: [UserProfile.self], inMemory: true)
    }
}
#endif

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
    @Bindable var profile: UserProfile
    @AppStorage("goodreads_is_connected") private var storedGoodreadsConnected = false

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
    @State private var duplicateCount: Int = 0
    @State private var showDuplicateAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false
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
        .navigationTitle(String(localized: "Goodreads"))
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
        .alert(String(localized: "Import Error"), isPresented: $showError) {
            Button(String(localized: "OK")) {}
        } message: {
            Text(errorMessage)
        }
        .alert(String(localized: "Duplicates Found"), isPresented: $showDuplicateAlert) {
            Button(String(localized: "Keep My Data")) {
                startImport(preferGoodreadsData: false)
            }
            Button(String(localized: "Prefer Goodreads Data")) {
                startImport(preferGoodreadsData: true)
            }
        } message: {
            Text(String.localizedStringWithFormat(String(localized: "We found %lld existing books. How should we handle conflicts?"), duplicateCount))
        }
        .sheet(isPresented: $showWebImport) {
            GoodreadsWebImportView(coordinator: coordinator)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
        .onAppear {
            Task {
                await refreshConnectionWithRetry()
            }
        }
        .onChange(of: coordinator.isConnected) { _, isConnected in
            storedGoodreadsConnected = isConnected
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

            Text(String(localized: "Keep this screen open while we import."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var automatedImportSection: some View {
        let displayConnected = coordinator.isConnected || storedGoodreadsConnected
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.doc")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(String(localized: "Import from Goodreads"))
                    .font(.headline)

                Spacer()

                connectionPill
            }

            Text(String(localized: "We'll import your library using Goodreads' official export. If Goodreads blocks it, you can upload the export CSV."))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                if displayConnected {
                    coordinator.start(syncOnly: true)
                } else {
                    showWebImport = true
                }
            } label: {
                Text(String(localized: displayConnected ? "Sync now" : "Import from Goodreads"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeColor.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(showCoordinatorProgress || isParsing || isImporting)

            if displayConnected {
                Button {
                    coordinator.disconnect()
                    storedGoodreadsConnected = false
                } label: {
                    Text(String(localized: "Disconnect Goodreads"))
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
        let connected = coordinator.isConnected || storedGoodreadsConnected
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
            Text(String(localized: connected ? "Connected" : "Not Connected"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(connected ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((connected ? Color.green.opacity(0.12) : Color.secondary.opacity(0.12)), in: Capsule())
        .onAppear {
            updatePulse(for: connected)
        }
        .onChange(of: coordinator.isConnected) { _, newValue in
            updatePulse(for: newValue)
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

                Text(String(localized: "Manual CSV upload"))
                    .font(.headline)
            }

            Text(String(localized: "Goodreads -> My Books -> Export Library -> Download CSV -> Upload here"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showImporter = true
            } label: {
                Text(String(localized: "Upload CSV"))
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
                    Text(String(localized: "Parsing CSV..."))
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

                Text(String(localized: "Import Complete"))
                    .font(.headline)

                summaryRow(title: String.localizedStringWithFormat(String(localized: "Imported %lld books"), result.importedCount), value: nil)
                if result.updatedCount > 0 {
                    summaryRow(title: String.localizedStringWithFormat(String(localized: "Updated %lld books"), result.updatedCount), value: nil)
                }
                if result.skippedCount > 0 {
                    summaryRow(title: String.localizedStringWithFormat(String(localized: "Skipped %lld rows"), result.skippedCount), value: nil)
                }
                if result.createdSessions > 0 {
                    summaryRow(title: String.localizedStringWithFormat(String(localized: "Created %lld imported sessions"), result.createdSessions), value: nil)
                }
                if result.reachedFreeLimit {
                    summaryRow(title: String(localized: "Stopped at free limit"), value: nil)

                    Button {
                        showUpgradeSheet = true
                    } label: {
                        Text(String(localized: "Upgrade to Pro"))
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

            Text(String.localizedStringWithFormat(String(localized: "Importing %lld of %lld books"), current, total))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let title = importProgressTitle, !title.isEmpty {
                Text(String.localizedStringWithFormat(String(localized: "Adding %@"), title))
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

            Text(String.localizedStringWithFormat(String(localized: "Fetching descriptions %lld of %lld"), current, total))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let title = descriptionProgressTitle, !title.isEmpty {
                Text(String.localizedStringWithFormat(String(localized: "Adding description for %@"), title))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func summaryRow(title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let value {
                Text(value)
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

        Task { @MainActor in
            do {
                let duplicates = try GoodreadsImportService.duplicateCount(
                    document: parsed,
                    modelContext: modelContext
                )
                if duplicates > 0 {
                    duplicateCount = duplicates
                    pendingDocument = parsed
                    showDuplicateAlert = true
                } else {
                    startImport(preferGoodreadsData: false)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
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

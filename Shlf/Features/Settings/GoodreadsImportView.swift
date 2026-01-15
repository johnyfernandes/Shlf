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

    @State private var showWebImport = false
    @State private var showImporter = false
    @State private var selectedFileName: String?
    @State private var document: GoodreadsImportDocument?
    @State private var result: GoodreadsImportResult?
    @State private var isParsing = false
    @State private var isImporting = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showUpgradeSheet = false

    @State private var options = GoodreadsImportOptions()

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profile)
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
                    automatedImportSection
                    manualImportSection
                    optionsSection
                    summarySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
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
        .sheet(isPresented: $showWebImport) {
            GoodreadsWebImportView { data in
                handleCSVData(data, fileName: "goodreads_library_export.csv")
            } onError: { message in
                errorMessage = message
                showError = true
            }
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
    }

    private var automatedImportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.doc")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(String(localized: "Import from Goodreads"))
                    .font(.headline)
            }

            Text(String(localized: "We'll import your library using Goodreads' official export. If Goodreads blocks it, you can upload the export CSV."))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showWebImport = true
            } label: {
                Text(String(localized: "Import from Goodreads"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(themeColor.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                GoodreadsImportCoordinator.clearWebsiteData()
            } label: {
                Text(String(localized: "Disconnect Goodreads"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(String(localized: "Import Options"))
                    .font(.headline)
            }

            VStack(spacing: 10) {
                Toggle(String(localized: "Use shelves for reading status"), isOn: $options.applyShelvesToStatus)
                Toggle(String(localized: "Import ratings & reviews"), isOn: $options.importRatingsAndNotes)
                Toggle(String(localized: "Use Goodreads dates"), isOn: $options.useDates)
                Toggle(String(localized: "Prefer Goodreads data for duplicates"), isOn: $options.preferGoodreadsData)
                Toggle(String(localized: "Create imported sessions (excluded from stats)"), isOn: $options.createImportedSessions)
            }
            .toggleStyle(SwitchToggleStyle(tint: themeColor.color))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let document {
                Text(String(localized: "Ready to import"))
                    .font(.headline)

                summaryRow(title: String(localized: "Total books"), value: "\(document.summary.totalRows)")
                summaryRow(title: String(localized: "Finished"), value: "\(document.summary.finishedCount)")
                summaryRow(title: String(localized: "Reading"), value: "\(document.summary.currentlyReadingCount)")
                summaryRow(title: String(localized: "Want to Read"), value: "\(document.summary.wantToReadCount)")
                summaryRow(title: String(localized: "DNF"), value: "\(document.summary.didNotFinishCount)")
                summaryRow(title: String(localized: "Ratings"), value: "\(document.summary.ratingsCount)")
                summaryRow(title: String(localized: "Dates read"), value: "\(document.summary.datesReadCount)")
                summaryRow(title: String(localized: "Custom shelves"), value: "\(document.summary.customShelvesCount)")

                if isImporting {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(String(localized: "Importing..."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Button {
                        importBooks()
                    } label: {
                        Text(String(localized: "Import Books"))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themeColor.color, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(isParsing || isImporting)
                }
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

        Task {
            do {
                let parsed = try GoodreadsImportService.parse(data: data)
                await MainActor.run {
                    document = parsed
                    isParsing = false
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

    private func importBooks() {
        guard let document else { return }
        isImporting = true
        result = nil

        Task { @MainActor in
            do {
                let importResult = try GoodreadsImportService.import(
                    document: document,
                    options: options,
                    modelContext: modelContext,
                    isProUser: isProUser
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

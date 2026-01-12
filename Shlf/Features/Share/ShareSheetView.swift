//
//  ShareSheetView.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI
import SwiftData
import Photos
import UIKit

struct ShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query private var profiles: [UserProfile]
    @Query private var sessions: [ReadingSession]
    @Query private var books: [Book]

    let book: Book?

    @State private var selectedTemplate: ShareTemplate
    @State private var selectedPeriod: SharePeriod = .last30
    @State private var selectedBackground: ShareBackgroundStyle = .paper
    @State private var selectedLayout: ShareLayoutStyle = .classic
    @State private var showGraph = true
    @State private var selectedGraphMetric: ShareGraphMetric = .pages
    @State private var selectedGraphStyle: ShareGraphStyle = .line
    @State private var showCover = true
    @State private var showProgressRing = true
    @State private var showQuote = true
    @State private var selectedQuoteSource: ShareQuoteSource = .latest
    @State private var selectedBookStats: [BookStatOption] = [.pagesRead, .timeRead, .sessions, .milestoneDate]
    @State private var selectedWrapStats: [WrapStatOption] = [.pages, .time, .sessions, .books]
    @State private var selectedStreakStats: [StreakStatOption] = [.bestStreak, .pagesToday, .minutesToday, .sessionsToday]
    @State private var bookContentOrder: [ShareContentBlock] = [.hero, .quote, .graph, .stats]
    @State private var wrapContentOrder: [ShareContentBlock] = [.graph, .stats]
    @State private var streakContentOrder: [ShareContentBlock] = [.hero, .graph, .stats]
    @State private var includeImportedSessions = false
    @State private var coverImage: UIImage?
    @State private var showInstagramAlert = false
    @State private var showSaveConfirmation = false
    @State private var saveResultMessage = "Saved to Photos."
    @State private var isRendering = false

    init(book: Book? = nil, defaultTemplate: ShareTemplate? = nil) {
        self.book = book
        let initialTemplate = defaultTemplate ?? (book == nil ? .wrap : .book)
        _selectedTemplate = State(initialValue: initialTemplate)
    }

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }

        let descriptor = FetchDescriptor<UserProfile>()
        if let existingAfterFetch = try? modelContext.fetch(descriptor).first {
            return existingAfterFetch
        }

        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }

    private var streaksEnabled: Bool {
        !profile.streaksPaused
    }

    private var availableTemplates: [ShareTemplate] {
        if book != nil {
            return streaksEnabled ? [.book, .wrap, .streak] : [.book, .wrap]
        }
        return streaksEnabled ? [.wrap, .streak] : [.wrap]
    }

    private var shareStyle: ShareCardStyle {
        ShareCardStyle(background: selectedBackground, accentColor: themeColor.color, layout: selectedLayout)
    }

    private var shareContent: ShareCardContent {
        switch selectedTemplate {
        case .book:
            return makeBookContent()
        case .wrap:
            return makeWrapContent()
        case .streak:
            return makeStreakContent()
        }
    }

    private var coverLoadKey: String {
        "\(selectedTemplate.rawValue)-\(showCover)-\(book?.coverImageURL?.absoluteString ?? "none")"
    }

    private var availableGraphMetrics: [ShareGraphMetric] {
        switch selectedTemplate {
        case .book:
            return [.pages, .minutes]
        case .wrap, .streak:
            return ShareGraphMetric.allCases
        }
    }

    private var bookQuotes: [Quote] {
        book?.quotes ?? []
    }

    private var hasQuotes: Bool {
        !bookQuotes.isEmpty
    }

    private var contentOrderBinding: Binding<[ShareContentBlock]> {
        switch selectedTemplate {
        case .book:
            return $bookContentOrder
        case .wrap:
            return $wrapContentOrder
        case .streak:
            return $streakContentOrder
        }
    }

    private var activeContentBlocks: [ShareContentBlock] {
        switch selectedTemplate {
        case .book:
            return activeBlocksForBook()
        case .wrap:
            return activeBlocksForWrap()
        case .streak:
            return activeBlocksForStreak()
        }
    }

    private var enabledContentBlocks: Set<ShareContentBlock> {
        Set(activeContentBlocks)
    }

    private var bookProgressValue: Double? {
        guard let book else { return nil }
        let totalPages = max(0, book.totalPages ?? 0)
        guard totalPages > 0 else { return nil }
        let currentPage = max(0, book.currentPage)
        return Double(currentPage) / Double(totalPages)
    }

    private var streakProgressValue: Double? {
        guard streaksEnabled else { return nil }
        let bestStreak = max(profile.longestStreak, profile.currentStreak)
        guard bestStreak > 0 else { return nil }
        return Double(profile.currentStreak) / Double(bestStreak)
    }

    private var bookGraphEnabled: Bool {
        guard let book else { return false }
        return showGraph && !sessionsForBook(book).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                templateSection
                appearanceSection
                contentSection
                graphSection
                quoteSection
                dataSection
                contentOrderSection
                statsSections
                actionsSection
            }
            .environment(\.editMode, .constant(.active))
            .tint(themeColor.color)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: coverLoadKey) {
            await loadCoverImageIfNeeded()
        }
        .onChange(of: selectedTemplate) { _, _ in
            guard !availableGraphMetrics.contains(selectedGraphMetric) else { return }
            selectedGraphMetric = availableGraphMetrics.first ?? .pages
        }
        .onChange(of: profile.streaksPaused) { _, paused in
            guard paused, selectedTemplate == .streak else { return }
            selectedTemplate = book == nil ? .wrap : .book
        }
        .alert("Instagram Not Available", isPresented: $showInstagramAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Install Instagram to share directly to Stories, or use the Share Image button instead.")
        }
        .alert("Image Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
    }

    private var previewCard: some View {
        ShareCardView(content: shareContent, style: shareStyle)
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.medium, radius: 12, y: 6)
    }

    private var previewSection: some View {
        Section("Preview") {
            previewCard
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    private var templateSection: some View {
        Section("Template") {
            if availableTemplates.count > 1 {
                Picker("Template", selection: $selectedTemplate) {
                    ForEach(availableTemplates) { template in
                        Text(template.title).tag(template)
                    }
                }
                .pickerStyle(.segmented)
            }

            if selectedTemplate == .wrap {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(SharePeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Background", selection: $selectedBackground) {
                ForEach(ShareBackgroundStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker("Layout", selection: $selectedLayout) {
                ForEach(ShareLayoutStyle.allCases) { layout in
                    Text(layout.title).tag(layout)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var contentSection: some View {
        Section("Content") {
            if selectedTemplate == .book {
                Toggle("Show cover", isOn: $showCover)

                Toggle("Show progress ring", isOn: $showProgressRing)
            }

            Toggle("Show graph", isOn: $showGraph)

            if selectedTemplate == .book, hasQuotes {
                Toggle("Show quote", isOn: $showQuote)
            }
        }
    }

    private var graphSection: some View {
        Group {
            if showGraph {
                Section("Graph") {
                    Picker("Metric", selection: $selectedGraphMetric) {
                        ForEach(availableGraphMetrics) { metric in
                            Text(metric.title).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Style", selection: $selectedGraphStyle) {
                        ForEach(ShareGraphStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var quoteSection: some View {
        Group {
            if selectedTemplate == .book, hasQuotes, showQuote {
                Section("Quote") {
                    Picker("Selection", selection: $selectedQuoteSource) {
                        ForEach(ShareQuoteSource.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var dataSection: some View {
        Section(
            footer: Text("Imported sessions are excluded from stats by default.")
        ) {
            Toggle("Include imported sessions", isOn: $includeImportedSessions)
        }
    }

    private var contentOrderSection: some View {
        Section(
            header: Text("Content Order"),
            footer: Text("Drag to reorder. Disabled blocks stay hidden.")
        ) {
            ContentOrderView(
                order: contentOrderBinding,
                enabledBlocks: enabledContentBlocks,
                accentColor: themeColor.color
            )
        }
    }

    private var statsSections: some View {
        Group {
            switch selectedTemplate {
            case .book:
                StatSelectorSections(
                    options: BookStatOption.allCases.map { StatOption(option: $0, title: $0.title, icon: $0.icon) },
                    selected: $selectedBookStats,
                    accentColor: themeColor.color
                )
            case .wrap:
                StatSelectorSections(
                    options: WrapStatOption.allCases.map { StatOption(option: $0, title: $0.title, icon: $0.icon) },
                    selected: $selectedWrapStats,
                    accentColor: themeColor.color
                )
            case .streak:
                StatSelectorSections(
                    options: StreakStatOption.allCases.map { StatOption(option: $0, title: $0.title, icon: $0.icon) },
                    selected: $selectedStreakStats,
                    accentColor: themeColor.color
                )
            }
        }
    }

    private var actionsSection: some View {
        Section("Share") {
            Button {
                handleShare(.save)
            } label: {
                Label("Save Image", systemImage: "square.and.arrow.down")
            }
            .disabled(isRendering)

            Button {
                handleShare(.instagram)
            } label: {
                Label("Share to Instagram Story", systemImage: "camera.fill")
            }
            .disabled(isRendering)

            Button {
                handleShare(.shareSheet)
            } label: {
                Label("Share Image", systemImage: "square.and.arrow.up")
            }
            .disabled(isRendering)

            if isRendering {
                ProgressView("Preparing your share...")
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .tint(themeColor.color)
    }

    private func loadCoverImageIfNeeded() async {
        guard selectedTemplate == .book,
              showCover,
              let url = book?.coverImageURL else {
            await MainActor.run {
                coverImage = nil
            }
            return
        }

        if let image = await ImageCacheManager.shared.getImage(for: url) {
            await MainActor.run {
                coverImage = image
            }
        }
    }

    private enum ShareAction {
        case instagram
        case shareSheet
        case save
    }

    private func handleShare(_ action: ShareAction) {
        Task { @MainActor in
            isRendering = true
            let image = renderShareImage()
            isRendering = false

            guard let image else { return }

            switch action {
            case .instagram:
                shareToInstagram(image)
            case .shareSheet:
                presentShareSheet(image)
            case .save:
                saveImage(image)
            }
        }
    }

    @MainActor
    private func renderShareImage() -> UIImage? {
        let size = CGSize(width: 1080, height: 1920)
        let view = ShareCardView(content: shareContent, style: shareStyle)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }

    private func shareToInstagram(_ image: UIImage) {
        guard let url = URL(string: "instagram-stories://share") else { return }
        guard UIApplication.shared.canOpenURL(url) else {
            showInstagramAlert = true
            return
        }

        guard let imageData = image.pngData() else { return }

        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]
        UIPasteboard.general.setItems(
            pasteboardItems,
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )

        UIApplication.shared.open(url)
    }

    private func presentShareSheet(_ image: UIImage) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
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

    private func saveImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    saveResultMessage = "Allow Photos access to save images."
                    showSaveConfirmation = true
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                Task { @MainActor in
                    if success {
                        saveResultMessage = "Saved to Photos."
                    } else {
                        saveResultMessage = error?.localizedDescription ?? "Couldn't save the image."
                    }
                    showSaveConfirmation = true
                }
            }
        }
    }
}

private enum ShareQuoteSource: String, CaseIterable, Identifiable {
    case latest
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .latest: return "Latest"
        case .random: return "Random"
        }
    }
}

private enum BookStatOption: String, CaseIterable, Identifiable {
    case pagesRead
    case totalPages
    case progressPercent
    case timeRead
    case sessions
    case milestoneDate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pagesRead: return "Pages Read"
        case .totalPages: return "Total Pages"
        case .progressPercent: return "Progress"
        case .timeRead: return "Time"
        case .sessions: return "Sessions"
        case .milestoneDate: return "Milestone"
        }
    }

    var icon: String {
        switch self {
        case .pagesRead: return "book.pages"
        case .totalPages: return "books.vertical"
        case .progressPercent: return "chart.pie.fill"
        case .timeRead: return "clock.fill"
        case .sessions: return "waveform.path.ecg"
        case .milestoneDate: return "calendar"
        }
    }
}

private enum WrapStatOption: String, CaseIterable, Identifiable {
    case pages
    case time
    case sessions
    case books
    case activeDays
    case avgPagesPerDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pages: return "Pages"
        case .time: return "Time"
        case .sessions: return "Sessions"
        case .books: return "Books Finished"
        case .activeDays: return "Active Days"
        case .avgPagesPerDay: return "Avg Pages/Day"
        }
    }

    var icon: String {
        switch self {
        case .pages: return "book.pages"
        case .time: return "clock.fill"
        case .sessions: return "sparkles"
        case .books: return "checkmark.seal.fill"
        case .activeDays: return "calendar.badge.clock"
        case .avgPagesPerDay: return "speedometer"
        }
    }
}

private enum StreakStatOption: String, CaseIterable, Identifiable {
    case currentStreak
    case bestStreak
    case pagesToday
    case minutesToday
    case sessionsToday
    case activeDays7

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentStreak: return "Current Streak"
        case .bestStreak: return "Best Streak"
        case .pagesToday: return "Pages Today"
        case .minutesToday: return "Minutes Today"
        case .sessionsToday: return "Sessions Today"
        case .activeDays7: return "Active Days (7d)"
        }
    }

    var icon: String {
        switch self {
        case .currentStreak: return "flame.fill"
        case .bestStreak: return "flame.circle.fill"
        case .pagesToday: return "book.pages"
        case .minutesToday: return "clock.fill"
        case .sessionsToday: return "sparkles"
        case .activeDays7: return "calendar"
        }
    }
}

private struct StatOption<Stat: Hashable & Identifiable>: Identifiable {
    let option: Stat
    let title: String
    let icon: String

    var id: Stat.ID { option.id }
}

private struct StatSelectorSections<Stat: Hashable & Identifiable>: View {
    let options: [StatOption<Stat>]
    @Binding var selected: [Stat]
    let accentColor: Color

    private let maxSelection = 4

    var body: some View {
        Section(
            header: statsHeader,
            footer: Text("Drag to reorder.")
        ) {
            if selected.isEmpty {
                Text("No stats selected.")
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            ForEach(selected, id: \.self) { option in
                let metadata = options.first { $0.option == option }
                StatRowView(
                    title: metadata?.title ?? "Stat",
                    icon: metadata?.icon ?? "circle",
                    accentColor: accentColor
                )
            }
            .onMove(perform: move)
        }

        Section(
            header: Text("Available"),
            footer: Text("Choose up to \(maxSelection) stats. Tap to add or remove.")
        ) {
            ForEach(options) { option in
                let isSelected = selected.contains(option.option)
                let canSelect = isSelected || selected.count < maxSelection

                Button {
                    toggle(option.option)
                } label: {
                    SelectableStatRow(
                        title: option.title,
                        icon: option.icon,
                        accentColor: accentColor,
                        isSelected: isSelected
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSelect)
                .opacity(canSelect ? 1 : 0.5)
            }
        }
    }

    private var statsHeader: some View {
        HStack {
            Text("Selected")
                .foregroundStyle(Theme.Colors.secondaryText)

            Spacer()

            Text("\(selected.count)/\(maxSelection)")
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .font(.caption)
    }

    private func toggle(_ option: Stat) {
        if let index = selected.firstIndex(of: option) {
            selected.remove(at: index)
            return
        }

        guard selected.count < maxSelection else { return }
        selected.append(option)
    }

    private func move(from source: IndexSet, to destination: Int) {
        selected.move(fromOffsets: source, toOffset: destination)
    }
}

private struct StatRowView: View {
    let title: String
    let icon: String
    let accentColor: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(accentColor)

            Text(title)
                .foregroundStyle(Theme.Colors.text)

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private struct SelectableStatRow: View {
    let title: String
    let icon: String
    let accentColor: Color
    let isSelected: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isSelected ? accentColor : Theme.Colors.secondaryText)

            Text(title)
                .foregroundStyle(Theme.Colors.text)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct ContentOrderView: View {
    @Binding var order: [ShareContentBlock]
    let enabledBlocks: Set<ShareContentBlock>
    let accentColor: Color

    var body: some View {
        ForEach(order) { block in
            let isEnabled = enabledBlocks.contains(block)
            ContentOrderRow(
                title: block.title,
                icon: block.icon,
                accentColor: accentColor,
                isEnabled: isEnabled
            )
        }
        .onMove(perform: move)
    }

    private func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
    }
}

private struct ContentOrderRow: View {
    let title: String
    let icon: String
    let accentColor: Color
    let isEnabled: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(accentColor)

            Text(title)
                .foregroundStyle(Theme.Colors.text)

            if !isEnabled {
                Text("Off")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.6)
    }
}

private extension ShareSheetView {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private var filteredSessions: [ReadingSession] {
        if includeImportedSessions {
            return sessions.filter { $0.countsTowardStats || $0.isImported }
        }
        return sessions.filter { $0.countsTowardStats }
    }

    private func sessionsForBook(_ book: Book) -> [ReadingSession] {
        let bookSessions = book.readingSessions ?? []
        if includeImportedSessions {
            return bookSessions.filter { $0.countsTowardStats || $0.isImported }
        }
        return bookSessions.filter { $0.countsTowardStats }
    }

    private func formatNumber(_ value: Int) -> String {
        ShareSheetView.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let mins = safeMinutes % 60
        if hours == 0 {
            return "\(formatNumber(mins))m"
        }
        if mins == 0 {
            return "\(formatNumber(hours))h"
        }
        return "\(formatNumber(hours))h \(formatNumber(mins))m"
    }

    private func formatDate(_ date: Date) -> String {
        ShareSheetView.dateFormatter.string(from: date)
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        "\(formatDate(start)) - \(formatDate(end))"
    }

    private func makeBookContent() -> ShareCardContent {
        guard let book else {
            return ShareCardContent(
                title: "Pick a Book",
                subtitle: "Choose a book to share",
                badge: nil,
                period: nil,
                coverImage: nil,
                progress: nil,
                progressText: nil,
                showProgressRing: false,
                hideProgressRingWhenComplete: true,
                quote: nil,
                graph: nil,
                blocks: [],
                stats: [],
                footer: "Shared with Shlf"
            )
        }

        let sessions = sessionsForBook(book)
        let minutesRead = sessions.reduce(0) { $0 + $1.durationMinutes }
        let sessionCount = sessions.count
        let totalPages = max(0, book.totalPages ?? 0)
        let currentPage = max(0, book.currentPage)
        let progress = totalPages > 0 ? Double(currentPage) / Double(totalPages) : nil
        let progressText: String? = totalPages > 0
            ? "\(formatNumber(currentPage)) / \(formatNumber(totalPages)) pages"
            : "\(formatNumber(currentPage)) pages"

        let date = book.isFinished ? book.dateFinished : book.dateStarted
        let dateLabel = book.isFinished ? "Finished" : "Started"
        let dateValue = date.map(formatDate) ?? "N/A"
        let period = date.map { "\(dateLabel) \(formatDate($0))" }

        let graph = showGraph ? bookGraph(for: sessions) : nil
        let quote = (showQuote && hasQuotes) ? bookQuote(for: book) : nil
        let blocks = activeBlocksForBook()
        let stats = selectedBookStats.map {
            bookStatItem(
                $0,
                currentPage: currentPage,
                totalPages: totalPages,
                minutesRead: minutesRead,
                sessionCount: sessionCount,
                dateLabel: dateLabel,
                dateValue: dateValue,
                progress: progress
            )
        }

        return ShareCardContent(
            title: book.title,
            subtitle: book.author,
            badge: book.readingStatus.shortName,
            period: period,
            coverImage: showCover ? coverImage : nil,
            progress: progress,
            progressText: progressText,
            showProgressRing: showProgressRing,
            hideProgressRingWhenComplete: true,
            quote: quote,
            graph: graph,
            blocks: blocks,
            stats: stats,
            footer: "Shared with Shlf"
        )
    }

    private func makeWrapContent() -> ShareCardContent {
        let range = selectedPeriod.dateRange()
        let sessionsInRange = filteredSessions.filter {
            $0.startDate >= range.start && $0.startDate <= range.end
        }
        let pagesRead = sessionsInRange.reduce(0) { $0 + $1.pagesRead }
        let minutesRead = sessionsInRange.reduce(0) { $0 + $1.durationMinutes }
        let sessionCount = sessionsInRange.count

        let graph = showGraph ? wrapGraph(for: sessionsInRange, range: range) : nil

        let booksFinished = books.filter { book in
            guard book.readingStatus == .finished,
                  let finishDate = book.dateFinished else { return false }
            return finishDate >= range.start && finishDate <= range.end
        }.count

        let daysInRange = max(1, daysBetween(start: range.start, end: range.end))
        let activeDays = activeDaysCount(for: sessionsInRange)
        let blocks = activeBlocksForWrap()
        let stats = selectedWrapStats.map {
            wrapStatItem(
                $0,
                pagesRead: pagesRead,
                minutesRead: minutesRead,
                sessionCount: sessionCount,
                booksFinished: booksFinished,
                daysInRange: daysInRange,
                activeDays: activeDays
            )
        }

        return ShareCardContent(
            title: "Reading Wrap",
            subtitle: selectedPeriod.title,
            badge: "Level \(profile.currentLevel)",
            period: formatDateRange(start: range.start, end: range.end),
            coverImage: nil,
            progress: nil,
            progressText: nil,
            showProgressRing: true,
            hideProgressRingWhenComplete: false,
            quote: nil,
            graph: graph,
            blocks: blocks,
            stats: stats,
            footer: "Shared with Shlf"
        )
    }

    private func makeStreakContent() -> ShareCardContent {
        let calendar = Calendar.current
        let today = Date()
        let todaySessions = filteredSessions.filter {
            calendar.isDate($0.startDate, inSameDayAs: today)
        }
        let pagesToday = todaySessions.reduce(0) { $0 + $1.pagesRead }
        let minutesToday = todaySessions.reduce(0) { $0 + $1.durationMinutes }
        let sessionCount = todaySessions.count

        let bestStreak = max(profile.longestStreak, profile.currentStreak)
        let progress = bestStreak > 0 ? Double(profile.currentStreak) / Double(bestStreak) : nil
        let progressText = bestStreak > 0
            ? "\(formatNumber(profile.currentStreak)) / \(formatNumber(bestStreak)) days"
            : nil

        let graph = showGraph ? streakGraph(for: filteredSessions) : nil
        let weekSessions = sessionsInRange(days: 7)
        let activeDays = activeDaysCount(for: weekSessions)
        let blocks = activeBlocksForStreak()
        let stats = selectedStreakStats.map {
            streakStatItem(
                $0,
                bestStreak: bestStreak,
                pagesToday: pagesToday,
                minutesToday: minutesToday,
                sessionCount: sessionCount,
                activeDays: activeDays,
                currentStreak: profile.currentStreak
            )
        }

        return ShareCardContent(
            title: "Streak Mode",
            subtitle: "Keep the fire alive",
            badge: "\(formatNumber(profile.currentStreak)) day streak",
            period: "Today",
            coverImage: nil,
            progress: progress,
            progressText: progressText,
            showProgressRing: true,
            hideProgressRingWhenComplete: false,
            quote: nil,
            graph: graph,
            blocks: blocks,
            stats: stats,
            footer: "Shared with Shlf"
        )
    }
}

private extension ShareSheetView {
    func wrapGraph(for sessions: [ReadingSession], range: (start: Date, end: Date)) -> ShareGraph {
        let bucketed = shouldBucketWeekly(range: range)
        let values = graphValues(for: sessions, range: range, metric: selectedGraphMetric)
        let subtitle = graphSubtitle(for: range, bucketed: bucketed)
        return ShareGraph(
            title: "\(selectedGraphMetric.title) Over Time",
            subtitle: subtitle,
            values: values,
            style: selectedGraphStyle
        )
    }

    func streakGraph(for sessions: [ReadingSession]) -> ShareGraph {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: end)) ?? end
        let range = (start: start, end: end)
        let values = graphValues(for: sessions, range: range, metric: selectedGraphMetric)
        return ShareGraph(
            title: "Last 7 Days",
            subtitle: selectedGraphMetric.title,
            values: values,
            style: selectedGraphStyle
        )
    }

    func bookGraph(for sessions: [ReadingSession]) -> ShareGraph? {
        guard !sessions.isEmpty else { return nil }

        let sorted = sessions.sorted { $0.startDate < $1.startDate }
        let recent = sorted.suffix(10)
        let values: [Double] = recent.map { session in
            switch selectedGraphMetric {
            case .pages:
                return Double(max(0, session.pagesRead))
            case .minutes:
                return Double(max(0, session.durationMinutes))
            case .sessions:
                return 1
            }
        }

        let title = "Recent Sessions"
        let subtitle = selectedGraphMetric.title
        return ShareGraph(title: title, subtitle: subtitle, values: values, style: selectedGraphStyle)
    }

    func graphValues(
        for sessions: [ReadingSession],
        range: (start: Date, end: Date),
        metric: ShareGraphMetric
    ) -> [Double] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: range.start)
        let endDay = calendar.startOfDay(for: range.end)
        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0

        let totalsByDay = dailyTotalsByDay(for: sessions, metric: metric)

        if dayCount > 90 {
            return weeklyTotals(from: startDay, to: endDay, totalsByDay: totalsByDay)
        }

        return dailyTotals(from: startDay, to: endDay, totalsByDay: totalsByDay)
    }

    func dailyTotalsByDay(for sessions: [ReadingSession], metric: ShareGraphMetric) -> [Date: Double] {
        let calendar = Calendar.current
        var totals: [Date: Double] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startDate)
            let value: Double
            switch metric {
            case .pages:
                value = Double(max(0, session.pagesRead))
            case .minutes:
                value = Double(max(0, session.durationMinutes))
            case .sessions:
                value = 1
            }
            totals[day, default: 0] += value
        }

        return totals
    }

    func dailyTotals(from start: Date, to end: Date, totalsByDay: [Date: Double]) -> [Double] {
        let calendar = Calendar.current
        var values: [Double] = []
        var day = start

        while day <= end {
            values.append(totalsByDay[day, default: 0])
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? end.addingTimeInterval(86400)
        }

        return values
    }

    func weeklyTotals(from start: Date, to end: Date, totalsByDay: [Date: Double]) -> [Double] {
        let calendar = Calendar.current
        var values: [Double] = []
        var current = start

        while current <= end {
            var weekTotal: Double = 0
            for offset in 0..<7 {
                let day = calendar.date(byAdding: .day, value: offset, to: current) ?? current
                if day > end { break }
                weekTotal += totalsByDay[day, default: 0]
            }
            values.append(weekTotal)
            current = calendar.date(byAdding: .day, value: 7, to: current) ?? end.addingTimeInterval(86400)
        }

        return values
    }

    func graphSubtitle(for range: (start: Date, end: Date), bucketed: Bool) -> String {
        let base = bucketed ? "Weekly totals" : "Daily totals"
        return "\(base) - \(formatDateRange(start: range.start, end: range.end))"
    }

    func shouldBucketWeekly(range: (start: Date, end: Date)) -> Bool {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: range.start)
        let endDay = calendar.startOfDay(for: range.end)
        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return dayCount > 90
    }

    func daysBetween(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
        return max(1, dayCount + 1)
    }

    func activeDaysCount(for sessions: [ReadingSession]) -> Int {
        let calendar = Calendar.current
        let days = sessions.map { calendar.startOfDay(for: $0.startDate) }
        return Set(days).count
    }

    func sessionsInRange(days: Int) -> [ReadingSession] {
        let calendar = Calendar.current
        let end = Date()
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: end)) ?? end
        return filteredSessions.filter { $0.startDate >= start && $0.startDate <= end }
    }

    func bookQuote(for book: Book) -> ShareQuote? {
        let quotes = book.quotes ?? []
        guard !quotes.isEmpty else { return nil }

        let quote: Quote?
        switch selectedQuoteSource {
        case .latest:
            quote = quotes.sorted { $0.dateAdded > $1.dateAdded }.first
        case .random:
            quote = quotes.randomElement()
        }

        guard let quote else { return nil }
        let attribution: String?
        if let page = quote.pageNumber {
            attribution = "Page \(formatNumber(page))"
        } else {
            attribution = nil
        }
        return ShareQuote(text: quote.text, attribution: attribution)
    }

    func bookStatItem(
        _ option: BookStatOption,
        currentPage: Int,
        totalPages: Int,
        minutesRead: Int,
        sessionCount: Int,
        dateLabel: String,
        dateValue: String,
        progress: Double?
    ) -> ShareStatItem {
        switch option {
        case .pagesRead:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(currentPage))
        case .totalPages:
            let value = totalPages > 0 ? formatNumber(totalPages) : "N/A"
            return ShareStatItem(icon: option.icon, label: option.title, value: value)
        case .progressPercent:
            let value = progress.map { "\(Int(($0 * 100).rounded()))%" } ?? "N/A"
            return ShareStatItem(icon: option.icon, label: option.title, value: value)
        case .timeRead:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatMinutes(minutesRead))
        case .sessions:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(sessionCount))
        case .milestoneDate:
            return ShareStatItem(icon: option.icon, label: dateLabel, value: dateValue)
        }
    }

    func wrapStatItem(
        _ option: WrapStatOption,
        pagesRead: Int,
        minutesRead: Int,
        sessionCount: Int,
        booksFinished: Int,
        daysInRange: Int,
        activeDays: Int
    ) -> ShareStatItem {
        switch option {
        case .pages:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(max(0, pagesRead)))
        case .time:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatMinutes(minutesRead))
        case .sessions:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(sessionCount))
        case .books:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(booksFinished))
        case .activeDays:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(activeDays))
        case .avgPagesPerDay:
            let average = Double(max(0, pagesRead)) / Double(max(1, daysInRange))
            let value = formatNumber(Int(average.rounded()))
            return ShareStatItem(icon: option.icon, label: option.title, value: value)
        }
    }

    func streakStatItem(
        _ option: StreakStatOption,
        bestStreak: Int,
        pagesToday: Int,
        minutesToday: Int,
        sessionCount: Int,
        activeDays: Int,
        currentStreak: Int
    ) -> ShareStatItem {
        switch option {
        case .currentStreak:
            return ShareStatItem(icon: option.icon, label: option.title, value: "\(formatNumber(currentStreak))d")
        case .bestStreak:
            return ShareStatItem(icon: option.icon, label: option.title, value: "\(formatNumber(bestStreak))d")
        case .pagesToday:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(max(0, pagesToday)))
        case .minutesToday:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatMinutes(minutesToday))
        case .sessionsToday:
            return ShareStatItem(icon: option.icon, label: option.title, value: formatNumber(sessionCount))
        case .activeDays7:
            return ShareStatItem(icon: option.icon, label: option.title, value: "\(formatNumber(activeDays))d")
        }
    }

    func activeBlocksForBook() -> [ShareContentBlock] {
        let heroEnabled = bookProgressValue != nil || (showCover && book?.coverImageURL != nil)
        let quoteEnabled = showQuote && hasQuotes
        let graphEnabled = bookGraphEnabled
        let statsEnabled = !selectedBookStats.isEmpty
        let availability: [ShareContentBlock: Bool] = [
            .hero: heroEnabled,
            .quote: quoteEnabled,
            .graph: graphEnabled,
            .stats: statsEnabled
        ]
        return bookContentOrder.filter { availability[$0] ?? false }
    }

    func activeBlocksForWrap() -> [ShareContentBlock] {
        let graphEnabled = showGraph
        let statsEnabled = !selectedWrapStats.isEmpty
        let availability: [ShareContentBlock: Bool] = [
            .graph: graphEnabled,
            .stats: statsEnabled
        ]
        return wrapContentOrder.filter { availability[$0] ?? false }
    }

    func activeBlocksForStreak() -> [ShareContentBlock] {
        let heroEnabled = streakProgressValue != nil
        let graphEnabled = showGraph
        let statsEnabled = !selectedStreakStats.isEmpty
        let availability: [ShareContentBlock: Bool] = [
            .hero: heroEnabled,
            .graph: graphEnabled,
            .stats: statsEnabled
        ]
        return streakContentOrder.filter { availability[$0] ?? false }
    }
}

struct LibraryShareSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]

    @State private var selectedFilter: LibraryShareFilter = .all
    @State private var selectedSort: LibraryShareSort = .recentlyAdded
    @State private var selectedGrid: LibraryShareGridStyle = .medium
    @State private var selectedBackground: ShareBackgroundStyle = .paper
    @State private var selectedLayout: ShareLayoutStyle = .classic
    @State private var showTitles = true
    @State private var showStatus = true
    @State private var showCountBadge = true
    @State private var showOverflow = true
    @State private var coverImages: [UUID: UIImage] = [:]
    @State private var showInstagramAlert = false
    @State private var showSaveConfirmation = false
    @State private var saveResultMessage = "Saved to Photos."
    @State private var isRendering = false

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                librarySection
                gridSection
                appearanceSection
                actionsSection
            }
            .tint(themeColor.color)
            .navigationTitle("Share Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: coverLoadKey) {
            await loadCoverImages()
        }
        .alert("Instagram Not Available", isPresented: $showInstagramAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Install Instagram to share directly to Stories, or use the Share Image button instead.")
        }
        .alert("Image Saved", isPresented: $showSaveConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveResultMessage)
        }
    }

    private var previewCard: some View {
        LibraryShareCardView(content: shareContent, style: shareStyle)
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.medium, radius: 12, y: 6)
    }

    private var previewSection: some View {
        Section("Preview") {
            previewCard
                .listRowInsets(EdgeInsets(top: Theme.Spacing.sm, leading: Theme.Spacing.md, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.md))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    private var librarySection: some View {
        Section("Library") {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(LibraryShareFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }

            Picker("Sort", selection: $selectedSort) {
                ForEach(LibraryShareSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }

            Toggle("Show count badge", isOn: $showCountBadge)
        }
    }

    private var gridSection: some View {
        Section(
            header: Text("Grid"),
            footer: Text("Use compact for dense shelves and large for hero covers.")
        ) {
            Picker("Grid size", selection: $selectedGrid) {
                ForEach(LibraryShareGridStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Show titles", isOn: $showTitles)
            Toggle("Show status icons", isOn: $showStatus)
            Toggle("Show overflow count", isOn: $showOverflow)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Background", selection: $selectedBackground) {
                ForEach(ShareBackgroundStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Picker("Layout", selection: $selectedLayout) {
                ForEach(ShareLayoutStyle.allCases) { layout in
                    Text(layout.title).tag(layout)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var actionsSection: some View {
        Section("Share") {
            Button {
                handleShare(.save)
            } label: {
                Label("Save Image", systemImage: "square.and.arrow.down")
            }
            .disabled(isRendering)

            Button {
                handleShare(.instagram)
            } label: {
                Label("Share to Instagram Story", systemImage: "camera.fill")
            }
            .disabled(isRendering)

            Button {
                handleShare(.shareSheet)
            } label: {
                Label("Share Image", systemImage: "square.and.arrow.up")
            }
            .disabled(isRendering)

            if isRendering {
                ProgressView("Preparing your share...")
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
        }
        .tint(themeColor.color)
    }

    private var shareStyle: ShareCardStyle {
        ShareCardStyle(background: selectedBackground, accentColor: themeColor.color, layout: selectedLayout)
    }

    private var shareContent: LibraryShareContent {
        LibraryShareContent(
            title: selectedFilter.shareTitle,
            subtitle: subtitleText,
            badge: badgeText,
            books: libraryShareBooks,
            overflowCount: overflowCount,
            showOverflow: showOverflow,
            gridStyle: selectedGrid,
            showTitles: showTitles,
            showStatus: showStatus,
            footer: "Shared with Shlf"
        )
    }

    private var subtitleText: String? {
        let filterLabel = selectedFilter.title
        let sortLabel = selectedSort.title
        if filterLabel == "All" {
            return sortLabel
        }
        return "\(filterLabel) • \(sortLabel)"
    }

    private var badgeText: String? {
        guard showCountBadge else { return nil }
        let count = filteredBooks.count
        let countText = formatNumber(count)
        let noun = count == 1 ? "Book" : "Books"
        return "\(countText) \(noun)"
    }

    private var filteredBooks: [Book] {
        guard let status = selectedFilter.status else {
            return allBooks
        }
        return allBooks.filter { $0.readingStatus == status }
    }

    private var sortedBooks: [Book] {
        switch selectedSort {
        case .recentlyAdded:
            return filteredBooks.sorted { $0.dateAdded > $1.dateAdded }
        case .title:
            return filteredBooks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .author:
            return filteredBooks.sorted {
                let comparison = $0.author.localizedCaseInsensitiveCompare($1.author)
                if comparison == .orderedSame {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return comparison == .orderedAscending
            }
        case .progress:
            return filteredBooks.sorted {
                let lhs = $0.progressPercentage
                let rhs = $1.progressPercentage
                if lhs == rhs {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return lhs > rhs
            }
        }
    }

    private var gridCapacity: Int {
        max(1, selectedGrid.maxItems)
    }

    private var showsOverflowTile: Bool {
        showOverflow && sortedBooks.count > gridCapacity && gridCapacity > 1
    }

    private var displayBooks: [Book] {
        if showsOverflowTile {
            return Array(sortedBooks.prefix(gridCapacity - 1))
        }
        return Array(sortedBooks.prefix(gridCapacity))
    }

    private var overflowCount: Int {
        guard showsOverflowTile else { return 0 }
        return max(0, sortedBooks.count - (gridCapacity - 1))
    }

    private var libraryShareBooks: [LibraryShareBook] {
        displayBooks.map { book in
            LibraryShareBook(
                id: book.id,
                title: book.title,
                author: book.author,
                status: book.readingStatus,
                coverImage: coverImages[book.id]
            )
        }
    }

    private var coverLoadKey: String {
        let ids = displayBooks.map { $0.id.uuidString }.joined(separator: "-")
        return "\(selectedFilter.rawValue)-\(selectedSort.rawValue)-\(selectedGrid.rawValue)-\(ids)"
    }

    private func loadCoverImages() async {
        let targets = displayBooks.compactMap { book -> (UUID, URL)? in
            guard let url = book.coverImageURL else { return nil }
            return (book.id, url)
        }

        guard !targets.isEmpty else { return }

        var loaded: [UUID: UIImage] = [:]
        for (id, url) in targets {
            if let image = await ImageCacheManager.shared.getImage(for: url) {
                loaded[id] = image
            }
        }

        await MainActor.run {
            var updated = coverImages
            for (id, image) in loaded {
                updated[id] = image
            }
            coverImages = updated
        }
    }

    private enum LibraryShareAction {
        case instagram
        case shareSheet
        case save
    }

    private func handleShare(_ action: LibraryShareAction) {
        Task { @MainActor in
            isRendering = true
            let image = renderShareImage()
            isRendering = false

            guard let image else { return }

            switch action {
            case .instagram:
                shareToInstagram(image)
            case .shareSheet:
                presentShareSheet(image)
            case .save:
                saveImage(image)
            }
        }
    }

    @MainActor
    private func renderShareImage() -> UIImage? {
        let size = CGSize(width: 1080, height: 1920)
        let view = LibraryShareCardView(content: shareContent, style: shareStyle)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.uiImage
    }

    private func shareToInstagram(_ image: UIImage) {
        guard let url = URL(string: "instagram-stories://share") else { return }
        guard UIApplication.shared.canOpenURL(url) else {
            showInstagramAlert = true
            return
        }

        guard let imageData = image.pngData() else { return }

        let pasteboardItems: [[String: Any]] = [
            ["com.instagram.sharedSticker.backgroundImage": imageData]
        ]
        UIPasteboard.general.setItems(
            pasteboardItems,
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )

        UIApplication.shared.open(url)
    }

    private func presentShareSheet(_ image: UIImage) {
        let activityVC = UIActivityViewController(
            activityItems: [image],
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

    private func saveImage(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    saveResultMessage = "Allow Photos access to save images."
                    showSaveConfirmation = true
                }
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { success, error in
                Task { @MainActor in
                    if success {
                        saveResultMessage = "Saved to Photos."
                    } else {
                        saveResultMessage = error?.localizedDescription ?? "Couldn't save the image."
                    }
                    showSaveConfirmation = true
                }
            }
        }
    }

    private func formatNumber(_ value: Int) -> String {
        LibraryShareSheetView.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
}

//
//  ShareSheetView.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI
import SwiftData
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
    @State private var selectedBackground: ShareBackgroundStyle = .aurora
    @State private var includeImportedSessions = false
    @State private var coverImage: UIImage?
    @State private var showInstagramAlert = false
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

    private var availableTemplates: [ShareTemplate] {
        if book != nil {
            return [.book, .wrap, .streak]
        }
        return [.wrap, .streak]
    }

    private var shareStyle: ShareCardStyle {
        ShareCardStyle(background: selectedBackground, accentColor: themeColor.color)
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
        "\(selectedTemplate.rawValue)-\(book?.coverImageURL?.absoluteString ?? "none")"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    previewCard
                    optionsSection
                    actionsSection
                }
                .padding(Theme.Spacing.md)
            }
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
        .alert("Instagram Not Available", isPresented: $showInstagramAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Install Instagram to share directly to Stories, or use the Share Image button instead.")
        }
    }

    private var previewCard: some View {
        ShareCardView(content: shareContent, style: shareStyle)
            .aspectRatio(9 / 16, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
            .shadow(color: Theme.Shadow.medium, radius: 12, y: 6)
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Customize")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.text)

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

            Picker("Style", selection: $selectedBackground) {
                ForEach(ShareBackgroundStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Include imported sessions", isOn: $includeImportedSessions)
                .tint(themeColor.color)

            Text("Imported sessions are excluded from stats by default.")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                handleShare(.instagram)
            } label: {
                Label("Share to Instagram Story", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .primaryButton(fullWidth: true, color: themeColor.color)
            .disabled(isRendering)

            Button {
                handleShare(.shareSheet)
            } label: {
                Label("Share Image", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .secondaryButton(fullWidth: true)
            .disabled(isRendering)

            Button {
                handleShare(.save)
            } label: {
                Label("Save Image", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(themeColor.color)
            .disabled(isRendering)

            if isRendering {
                ProgressView("Preparing your share...")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    private func loadCoverImageIfNeeded() async {
        guard selectedTemplate == .book,
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
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
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

        let stats = [
            ShareStatItem(
                icon: "book.pages",
                label: "Pages Read",
                value: formatNumber(currentPage)
            ),
            ShareStatItem(
                icon: "clock.fill",
                label: "Time",
                value: formatMinutes(minutesRead)
            ),
            ShareStatItem(
                icon: "waveform.path.ecg",
                label: "Sessions",
                value: formatNumber(sessionCount)
            ),
            ShareStatItem(
                icon: "calendar",
                label: dateLabel,
                value: dateValue
            )
        ]

        return ShareCardContent(
            title: book.title,
            subtitle: book.author,
            badge: book.readingStatus.shortName,
            period: period,
            coverImage: coverImage,
            progress: progress,
            progressText: progressText,
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

        let booksFinished = books.filter { book in
            guard book.readingStatus == .finished,
                  let finishDate = book.dateFinished else { return false }
            return finishDate >= range.start && finishDate <= range.end
        }.count

        let stats = [
            ShareStatItem(
                icon: "book.pages",
                label: "Pages",
                value: formatNumber(max(0, pagesRead))
            ),
            ShareStatItem(
                icon: "clock.fill",
                label: "Time",
                value: formatMinutes(minutesRead)
            ),
            ShareStatItem(
                icon: "sparkles",
                label: "Sessions",
                value: formatNumber(sessionCount)
            ),
            ShareStatItem(
                icon: "checkmark.seal.fill",
                label: "Books",
                value: formatNumber(booksFinished)
            )
        ]

        return ShareCardContent(
            title: "Reading Wrap",
            subtitle: selectedPeriod.title,
            badge: "Level \(profile.currentLevel)",
            period: formatDateRange(start: range.start, end: range.end),
            coverImage: nil,
            progress: nil,
            progressText: nil,
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

        let stats = [
            ShareStatItem(
                icon: "flame.fill",
                label: "Best Streak",
                value: "\(formatNumber(bestStreak))d"
            ),
            ShareStatItem(
                icon: "book.pages",
                label: "Pages Today",
                value: formatNumber(max(0, pagesToday))
            ),
            ShareStatItem(
                icon: "clock.fill",
                label: "Minutes",
                value: formatMinutes(minutesToday)
            ),
            ShareStatItem(
                icon: "sparkles",
                label: "Sessions",
                value: formatNumber(sessionCount)
            )
        ]

        return ShareCardContent(
            title: "Streak Mode",
            subtitle: "Keep the fire alive",
            badge: "\(formatNumber(profile.currentStreak)) day streak",
            period: "Today",
            coverImage: nil,
            progress: progress,
            progressText: progressText,
            stats: stats,
            footer: "Shared with Shlf"
        )
    }
}

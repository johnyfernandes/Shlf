//
//  BookDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import OSLog
import SwiftData
import UIKit

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    @State private var showLogSession = false
    @State private var showEditBook = false
    @State private var showDeleteAlert = false
    @State private var showConfetti = false
    @State private var showAddQuote = false
    @State private var showChangeEdition = false
    @State private var showStatusChangeAlert = false
    @State private var pendingStatus: ReadingStatus?
    @State private var savedProgress: Int?
    @State private var sessionToDelete: ReadingSession?
    @State private var showDeleteSessionAlert = false
    @State private var showFinishOptions = false
    @State private var showFinishLog = false
    @State private var showShareSheet = false
    @State private var playShimmer: CGFloat = -40
    @State private var showBookStatsSettings = false
    @State private var showBookDetailCustomization = false
    @State private var selectedBookStat: BookStatsCardType?
    @State private var bookStatsRange: BookStatsRange = .all
    @State private var bookStatsRangeOffset = 0
    @State private var hasInitializedBookStatsRange = false
    @State private var showSubjectPicker = false
    @State private var selectedSubjects: [String] = []

    private var profile: UserProfile? {
        profiles.first
    }

    private var hasActiveSession: Bool {
        activeSessions.first != nil
    }

    private var hasTrackedSessions: Bool {
        (book.readingSessions ?? []).contains { $0.countsTowardStats }
    }

    private var needsPageCount: Bool {
        guard let totalPages = book.totalPages else { return true }
        return totalPages <= 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background that follows theme
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
                VStack(spacing: 0) {
                    // Hero header with cover and status
                    heroHeader

                    // Main content
                    VStack(spacing: 20) {
                        // Active session banner
                        if hasActiveSession {
                            activeSessionBanner
                        }

                        // Progress interface (when currently reading)
                        if book.readingStatus == .currentlyReading {
                            progressInterface
                        }

                        if needsPageCount {
                            missingPagesCard
                        }

                        // Dynamic sections based on user's order and visibility preferences
                        ForEach(profile?.bookDetailSections ?? BookDetailSection.allCases, id: \.self) { section in
                            sectionView(for: section)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
        }
        .confetti(isActive: $showConfetti)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(book.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if book.readingStatus == .currentlyReading {
                        Button {
                            markAsFinished()
                        } label: {
                            Label {
                                Text(verbatim: localized("BookDetail.MarkFinished", locale: locale))
                            } icon: {
                                Image(systemName: "checkmark.circle")
                            }
                        }

                        Button {
                            updateReadingStatus(to: .didNotFinish)
                        } label: {
                            Label {
                                Text(verbatim: localized("BookDetail.MarkAsDNF", locale: locale))
                            } icon: {
                                Image(systemName: "xmark.circle")
                            }
                        }

                        Divider()
                    }

                    if book.readingStatus == .currentlyReading {
                        Button {
                            showAddQuote = true
                        } label: {
                            Label {
                                Text(verbatim: localized("BookDetail.AddQuote", locale: locale))
                            } icon: {
                                Image(systemName: "quote.bubble")
                            }
                        }

                        Divider()
                    }

                    Button {
                        showShareSheet = true
                    } label: {
                        Label {
                            Text(verbatim: localized("BookDetail.Share", locale: locale))
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    Button {
                        showEditBook = true
                    } label: {
                        Label {
                            Text(verbatim: localized("BookDetail.EditBook", locale: locale))
                        } icon: {
                            Image(systemName: "pencil.line")
                        }
                    }

                    if canChangeEdition {
                        Button {
                            showChangeEdition = true
                        } label: {
                            Label {
                                Text(verbatim: localized("BookDetail.ChangeEdition", locale: locale))
                            } icon: {
                                Image(systemName: "books.vertical")
                            }
                        }
                    }

                    if profile != nil {
                        Button {
                            showBookDetailCustomization = true
                        } label: {
                            Label {
                                Text(verbatim: localized("BookDetail.CustomizeBookDetails", locale: locale))
                            } icon: {
                                Image(systemName: "slider.horizontal.3")
                            }
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label {
                            Text(verbatim: localized("BookDetail.DeleteBook", locale: locale))
                        } icon: {
                            Image(systemName: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(themeColor.color)
                }
            }
        }
        .sheet(isPresented: $showLogSession) {
            LogReadingSessionView(book: book)
        }
        .sheet(isPresented: $showEditBook) {
            EditBookView(book: book)
        }
        .sheet(isPresented: $showChangeEdition) {
            ChangeEditionView(book: book)
        }
        .sheet(isPresented: $showAddQuote) {
            AddQuoteView(book: book)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(book: book)
        }
        .sheet(item: $selectedBookStat) { stat in
            BookStatDetailView(
                stat: stat,
                book: book,
                summary: bookStatsSummary,
                rangeLabel: bookStatsRangeLabel,
                onPrimaryAction: {
                    showLogSession = true
                }
            )
        }
        .sheet(isPresented: $showBookStatsSettings) {
            if let profile {
                NavigationStack {
                    BookStatsSettingsView(profile: profile)
                }
            }
        }
        .sheet(isPresented: $showBookDetailCustomization) {
            if let profile {
                NavigationStack {
                    BookDetailCustomizationView(profile: profile)
                }
            }
        }
        .sheet(isPresented: $showSubjectPicker) {
            if let profile {
                SubjectPickerView(profile: profile, selectedSubjects: $selectedSubjects)
            }
        }
        .alert(Text(verbatim: localized("BookDetail.DeleteBook.Title", locale: locale)), isPresented: $showDeleteAlert) {
            Button(role: .destructive) {
                deleteBook()
            } label: {
                Text(verbatim: localized("Common.Delete", locale: locale))
            }
            Button(role: .cancel) {
            } label: {
                Text(verbatim: localized("Common.Cancel", locale: locale))
            }
        } message: {
                Text(
                    String.localizedStringWithFormat(
                        localized("BookDetail.DeleteBook.Message %@",
                                  locale: locale),
                        book.title
                    )
                )
        }
        .onAppear {
            if !hasInitializedBookStatsRange {
                bookStatsRange = profile?.bookStatsRange ?? .all
                hasInitializedBookStatsRange = true
            }
            if selectedSubjects.isEmpty {
                selectedSubjects = book.subjects ?? []
            }
            syncSubjectLibrary()
            ensureBookStatsSection()
        }
        .onChange(of: showSubjectPicker) { _, isPresented in
            if !isPresented {
                applySubjectSelection()
            }
        }
        .onChange(of: book.subjects) { _, _ in
            syncSubjectLibrary()
        }
        .onChange(of: bookStatsRange) { _, newValue in
            bookStatsRangeOffset = 0
            if let profile {
                profile.bookStatsRange = newValue
                try? modelContext.save()
            }
        }
        .onChange(of: profile?.bookStatsRangeRawValue) { _, newValue in
            guard let newValue,
                  let newRange = BookStatsRange(rawValue: newValue),
                  newRange != bookStatsRange else {
                return
            }
            bookStatsRange = newRange
            bookStatsRangeOffset = 0
        }
        .alert(Text(verbatim: localized("BookDetail.ChangeStatus.Title", locale: locale)), isPresented: $showStatusChangeAlert) {
            Button(role: .destructive) {
                if let status = pendingStatus {
                    updateReadingStatus(to: status)
                }
                pendingStatus = nil
            } label: {
                Text(verbatim: localized("BookDetail.ChangeStatus.Confirm", locale: locale))
            }
            Button(role: .cancel) {
                pendingStatus = nil
            } label: {
                Text(verbatim: localized("Common.Cancel", locale: locale))
            }
        } message: {
            if pendingStatus != nil {
                Text(
                    String.localizedStringWithFormat(
                        localized("BookDetail.ChangeStatus.Message %lld", locale: locale),
                        book.currentPage
                    )
                )
            }
        }
        .alert(Text(verbatim: localized("BookDetail.DeleteSession.Title", locale: locale)), isPresented: $showDeleteSessionAlert) {
            Button(role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
                sessionToDelete = nil
            } label: {
                Text(verbatim: localized("Common.Delete", locale: locale))
            }
            Button(role: .cancel) {
                sessionToDelete = nil
            } label: {
                Text(verbatim: localized("Common.Cancel", locale: locale))
            }
        } message: {
            Text(verbatim: localized("BookDetail.DeleteSession.Message", locale: locale))
        }
        .confirmationDialog(Text(verbatim: localized("BookDetail.FinishBook.Title", locale: locale)), isPresented: $showFinishOptions, titleVisibility: .visible) {
            Button {
                updateReadingStatus(to: .finished)
            } label: {
                Text(verbatim: localized("BookDetail.FinishBook.Exclude", locale: locale))
            }
            Button {
                showFinishLog = true
            } label: {
                Text(verbatim: localized("BookDetail.FinishBook.Log", locale: locale))
            }
            Button(role: .cancel) {
            } label: {
                Text(verbatim: localized("Common.Cancel", locale: locale))
            }
        } message: {
            Text(verbatim: localized("BookDetail.FinishBook.Message", locale: locale))
        }
        .sheet(isPresented: $showFinishLog) {
            FinishBookLogView(book: book) {
                showConfetti = true
            }
        }
    }

    private var canChangeEdition: Bool {
        if book.openLibraryWorkID != nil { return true }
        if book.openLibraryEditionID != nil { return true }
        if let isbn = book.isbn, !isbn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return false
    }

    // MARK: - Section Rendering

    @ViewBuilder
    private func sectionView(for section: BookDetailSection) -> some View {
        // Check if section should be visible
        if profile?.isBookDetailSectionVisible(section) ?? true {
            switch section {
            case .bookStats:
                bookStatsSection

            case .description:
                if let description = book.bookDescription, !description.isEmpty {
                    descriptionSection(description)
                } else {
                    emptySectionCard(
                        icon: "text.alignleft",
                        title: "BookDetail.Empty.Description.Title",
                        message: "BookDetail.Empty.Description.Message",
                        actionTitle: "BookDetail.Empty.Description.Action"
                    ) {
                        showEditBook = true
                    }
                }

            case .lastPosition:
                if let lastPos = book.lastPosition {
                    lastPositionSection(lastPos)
                } else {
                    emptySectionCard(
                        icon: "bookmark",
                        title: "BookDetail.Empty.LastPosition.Title",
                        message: "BookDetail.Empty.LastPosition.Message",
                        actionTitle: "BookDetail.Empty.LastPosition.Action"
                    ) {
                        showLogSession = true
                    }
                }

            case .quotes:
                if let quotes = book.quotes, !quotes.isEmpty {
                    quotesSection(quotes)
                } else {
                    emptySectionCard(
                        icon: "quote.bubble",
                        title: "BookDetail.Empty.Quotes.Title",
                        message: "BookDetail.Empty.Quotes.Message",
                        actionTitle: "BookDetail.Empty.Quotes.Action"
                    ) {
                        showAddQuote = true
                    }
                }

            case .notes:
                if !book.notes.isEmpty {
                    notesSection
                } else {
                    emptySectionCard(
                        icon: "note.text",
                        title: "BookDetail.Empty.Notes.Title",
                        message: "BookDetail.Empty.Notes.Message",
                        actionTitle: "BookDetail.Empty.Notes.Action"
                    ) {
                        showEditBook = true
                    }
                }

            case .subjects:
                if let subjects = book.subjects, !subjects.isEmpty {
                    subjectsSection(subjects)
                } else {
                    emptySectionCard(
                        icon: "tag",
                        title: "BookDetail.Empty.Subjects.Title",
                        message: "BookDetail.Empty.Subjects.Message",
                        actionTitle: "BookDetail.Empty.Subjects.Action"
                    ) {
                        selectedSubjects = book.subjects ?? []
                        showSubjectPicker = true
                    }
                }

            case .metadata:
                metadataSection

            case .readingHistory:
                let hideAuto = profile?.hideAutoSessionsIPhone ?? false
                let hasVisibleSessions = (book.readingSessions ?? []).contains(where: { session in
                    hideAuto ? !session.isAutoGenerated : true
                })
                if hasVisibleSessions {
                    readingHistorySection
                } else {
                    emptySectionCard(
                        icon: "clock.arrow.circlepath",
                        title: "BookDetail.Empty.Sessions.Title",
                        message: "BookDetail.Empty.Sessions.Message",
                        actionTitle: "BookDetail.Empty.Sessions.Action"
                    ) {
                        showLogSession = true
                    }
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 20) {
            // Cover image with shadow
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 130,
                height: 195
            )
            .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
            .padding(.top, 20)

            heroActions

            // Type badge
            if book.bookType != .physical {
                HStack(spacing: 4) {
                    Image(systemName: book.bookType.icon)
                        .font(.caption2)
                    Text(book.bookType.displayNameKey)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(Theme.Colors.tertiaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }

            // Saved progress indicator
            if let saved = book.savedCurrentPage, book.readingStatus != .currentlyReading {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                    Text(String.localizedStringWithFormat(
                        localized("BookDetail.SavedAtPageFormat %lld", locale: locale),
                        saved
                    ))
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.15), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    // MARK: - Active Session Banner

    private var activeSessionBanner: some View {
        Button {
            Haptics.impact(.light)
            showLogSession = true
        } label: {
            HStack(spacing: 12) {
                // Animated pulse indicator
                ZStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)

                    Circle()
                        .stroke(.green.opacity(0.3), lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .modifier(PulseAnimation())
                }

                if let activeSession = activeSessions.first {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: localized("BookDetail.ActiveSession", locale: locale))
                            .font(.subheadline.weight(.semibold))

                        Text(
                            String.localizedStringWithFormat(
                                localized("BookDetail.ActiveSession.DetailFormat %@ %lld", locale: locale),
                                activeSession.sourceDevice,
                                activeSession.currentPage
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.green.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.green.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress Interface

    private var progressInterface: some View {
        Group {
            if profile?.useProgressSlider == true {
                ProgressSliderView(
                    book: book,
                    incrementAmount: profile?.pageIncrementAmount ?? 1,
                    showButtons: profile?.showSliderButtons ?? false,
                    showConfetti: $showConfetti,
                    onSave: { pagesRead in
                        handleProgressSave(pagesRead: pagesRead)
                    }
                )
            } else {
                QuickProgressStepper(
                    book: book,
                    incrementAmount: profile?.pageIncrementAmount ?? 1,
                    showConfetti: $showConfetti,
                    onSave: { pagesRead in
                        handleProgressSave(pagesRead: pagesRead)
                    }
                )
            }
        }
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        ))
    }

    private var missingPagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "number.circle")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(verbatim: localized("BookDetail.AddTotalPages.Title", locale: locale))
                    .font(.headline)
            }

            Text(verbatim: localized("BookDetail.AddTotalPages.Message", locale: locale))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showEditBook = true
            } label: {
                Text(localized("Add pages", locale: locale))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Stats Overview

    private var bookStatsCards: [BookStatsCardType] {
        guard let profile else { return BookStatsCardType.allCases }
        let cards = profile.bookStatsCards
        return cards.isEmpty ? BookStatsCardType.allCases : cards
    }

    private var bookStatsSessions: [ReadingSession] {
        let includeImported = profile?.bookStatsIncludeImported ?? false
        let includeExcluded = profile?.bookStatsIncludeExcluded ?? false
        let range = bookStatsRangeWindow

        return (book.readingSessions ?? [])
            .filter { session in
                (includeImported || !session.isImported) &&
                (includeExcluded || session.countsTowardStats) &&
                session.startDate >= range.start &&
                session.startDate <= range.end
            }
            .sorted(by: { $0.startDate > $1.startDate })
    }

    private var bookStatsSummary: BookStatsSummary {
        BookStatsSummary.build(book: book, sessions: bookStatsSessions)
    }

    private var bookStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Stats")
                    .font(.headline)

                Spacer()

                Menu {
                    Picker("Range", selection: $bookStatsRange) {
                        ForEach(BookStatsRange.allCases) { range in
                            Text(range.titleKey).tag(range)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(bookStatsRange.titleKey)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(Theme.Colors.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.tertiaryBackground, in: Capsule())
                }

                Button {
                    showBookStatsSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor.color)
                        .padding(8)
                        .background(themeColor.color.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(profile == nil)
            }

            HStack(spacing: 8) {
                if bookStatsRange != .all {
                    Button {
                        bookStatsRangeOffset += 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(canShiftBookStatsRangeBack ? themeColor.color : Theme.Colors.tertiaryText)
                    .disabled(!canShiftBookStatsRangeBack)
                }

                Text(bookStatsRangeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if bookStatsRange != .all {
                    Button {
                        bookStatsRangeOffset = max(0, bookStatsRangeOffset - 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(bookStatsRangeOffset == 0 ? Theme.Colors.tertiaryText : themeColor.color)
                    .disabled(bookStatsRangeOffset == 0)
                }
            }

            if bookStatsSummary.sessionCount == 0 {
                InlineEmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No stats yet",
                    message: "Log a session to see stats for this book.",
                    actionTitle: "Log session"
                ) {
                    showLogSession = true
                }
                .padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(bookStatsCards) { card in
                        BookStatCardView(
                            title: bookStatTitle(for: card, summary: bookStatsSummary),
                            indicator: card.indicator,
                            accent: card.accent.color(themeColor: themeColor)
                        ) {
                            selectedBookStat = card
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var bookStatsRangeWindow: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch bookStatsRange {
        case .all:
            let earliest = (book.readingSessions ?? []).map(\.startDate).min() ?? today
            return (calendar.startOfDay(for: earliest), Date())
        case .year:
            let currentYear = calendar.component(.year, from: Date()) - bookStatsRangeOffset
            let start = calendar.date(from: DateComponents(year: currentYear, month: 1, day: 1)) ?? today
            if bookStatsRangeOffset == 0 {
                return (start, Date())
            }
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start) ?? Date()
            return (start, calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end)
        default:
            let rangeDays = max(1, bookStatsRange.days ?? 1)
            let end = calendar.date(byAdding: .day, value: -bookStatsRangeOffset * rangeDays, to: today) ?? today
            let start = calendar.date(byAdding: .day, value: -(rangeDays - 1), to: end) ?? end
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            return (start, endOfDay)
        }
    }

    private var bookStatsRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        let range = bookStatsRangeWindow
        if bookStatsRange == .all {
            return "\(formatter.string(from: range.start)) – \(formatter.string(from: range.end))"
        }
        return "\(formatter.string(from: range.start)) – \(formatter.string(from: range.end))"
    }

    private var canShiftBookStatsRangeBack: Bool {
        guard bookStatsRange != .all else { return false }
        let earliest = (book.readingSessions ?? []).map(\.startDate).min()
        guard let earliest else { return false }
        return bookStatsRangeWindow.start > earliest
    }

    private func bookStatTitle(for stat: BookStatsCardType, summary: BookStatsSummary) -> Text {
        let accent = stat.accent.color(themeColor: themeColor)
        switch stat {
        case .pagesPercent:
            var composed = AttributedString(localized("You read", locale: locale))
            composed += AttributedString(" ")
            composed += coloredValueWithUnit(
                value: summary.totalPagesRead,
                singular: localized("page", locale: locale),
                plural: localized("pages", locale: locale),
                accent: accent
            )
            if let percent = summary.percentRead {
                composed += AttributedString(" ")
                composed += coloredText("\(percent)", color: accent)
                composed += AttributedString("%")
            }
            composed += AttributedString(".")
            return Text(composed)
        case .timeRead:
            var composed = AttributedString(localized("You read for", locale: locale))
            composed += AttributedString(" ")
            composed += coloredText(formatMinutes(summary.totalMinutesRead), color: accent)
            composed += AttributedString(".")
            return Text(composed)
        case .sessionCount:
            var composed = AttributedString(localized("You logged", locale: locale))
            composed += AttributedString(" ")
            composed += coloredValueWithUnit(
                value: summary.sessionCount,
                singular: localized("session", locale: locale),
                plural: localized("sessions", locale: locale),
                accent: accent
            )
            composed += AttributedString(".")
            return Text(composed)
        case .averagePages:
            var composed = AttributedString(localized("Average", locale: locale))
            composed += AttributedString(" ")
            composed += coloredText(formatNumber(summary.averagePagesPerSession), color: accent)
            composed += AttributedString(" ")
            composed += AttributedString(localized("pages per session.", locale: locale))
            return Text(composed)
        case .averageSpeed:
            var composed = AttributedString(localized("Average", locale: locale))
            composed += AttributedString(" ")
            composed += coloredText(formatNumber(summary.averagePagesPerHour), color: accent)
            composed += AttributedString(" ")
            composed += AttributedString(localized("pages per hour.", locale: locale))
            return Text(composed)
        case .longestSession:
            if summary.longestSessionMinutes > 0 {
                var composed = AttributedString(localized("Longest session", locale: locale))
                composed += AttributedString(" ")
                composed += coloredText(formatMinutes(summary.longestSessionMinutes), color: accent)
                composed += AttributedString(".")
                return Text(composed)
            }
            var composed = AttributedString(localized("Longest session", locale: locale))
            composed += AttributedString(" ")
            composed += coloredValueWithUnit(
                value: summary.longestSessionPages,
                singular: localized("page", locale: locale),
                plural: localized("pages", locale: locale),
                accent: accent
            )
            composed += AttributedString(".")
            return Text(composed)
        case .streak:
            var composed = AttributedString(localized("Your book streak was", locale: locale))
            composed += AttributedString(" ")
            composed += coloredValueWithUnit(
                value: summary.streakDays,
                singular: localized("day", locale: locale),
                plural: localized("days", locale: locale),
                accent: accent
            )
            composed += AttributedString(".")
            return Text(composed)
        case .daysSinceLast:
            if let lastReadDate = summary.lastReadDate {
                let (relative, highlightValue) = relativeTimeString(from: lastReadDate, locale: locale)
                var composed = AttributedString(localized("Last read", locale: locale))
                composed += AttributedString(" ")
                composed += coloredNumberInFormattedString(relative, number: highlightValue, accent: accent)
                composed += AttributedString(".")
                return Text(composed)
            }
            return Text("No reads yet")
        case .firstLastDate:
            if let first = summary.firstReadDate, let last = summary.lastReadDate {
                var composed = AttributedString(localized("First read", locale: locale))
                composed += AttributedString(" ")
                composed += coloredText(formatDate(first), color: accent)
                composed += AttributedString(" • ")
                composed += coloredText(formatDate(last), color: accent)
                return Text(composed)
            }
            return Text(localized("No read dates yet", locale: locale))
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return String.localizedStringWithFormat(localized("%lldh", locale: locale), hours)
            }
            return String.localizedStringWithFormat(localized("%lldh %lldm", locale: locale), hours, mins)
        }
        return String.localizedStringWithFormat(localized("%lldm", locale: locale), minutes)
    }

    private func formatDays(_ value: Int) -> String {
        String.localizedStringWithFormat(localized("%lld days", locale: locale), value)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func formatNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }

    private func coloredValueWithUnit(
        value: Int,
        singular: String,
        plural: String,
        accent: Color
    ) -> AttributedString {
        let numberString = NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
        let unitText = value == 1 ? singular : plural
        var attributed = coloredText(numberString, color: accent)
        attributed += AttributedString(" ")
        attributed += AttributedString(unitText)
        return attributed
    }

    private func coloredNumberInFormattedString(
        _ formatted: String,
        number: Int,
        accent: Color
    ) -> AttributedString {
        let numberString = NumberFormatter.localizedString(from: NSNumber(value: number), number: .decimal)
        var attributed = AttributedString(formatted)
        if let range = attributed.range(of: numberString) {
            attributed[range].foregroundColor = UIColor(accent)
        }
        return attributed
    }

    private func coloredText(_ text: String, color: Color) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.foregroundColor = UIColor(color)
        return attributed
    }

    private func relativeTimeString(from date: Date, locale: Locale) -> (String, Int) {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        let elapsedSeconds = max(1, Int(Date().timeIntervalSince(date)))
        let unitValue = relativeUnitValue(for: elapsedSeconds)
        let interval = -Double(elapsedSeconds)
        return (formatter.localizedString(fromTimeInterval: interval), unitValue)
    }

    private func relativeUnitValue(for seconds: Int) -> Int {
        if seconds < 60 { return seconds }
        if seconds < 3600 { return max(1, seconds / 60) }
        if seconds < 86_400 { return max(1, seconds / 3600) }
        return max(1, seconds / 86_400)
    }

    private func syncSubjectLibrary() {
        guard let profile else { return }
        let canonical = profile.registerSubjects(book.subjects ?? [])
        let normalizedExisting = (book.subjects ?? []).map { UserProfile.normalizedSubjectKey($0) }
        let normalizedCanonical = canonical.map { UserProfile.normalizedSubjectKey($0) }
        if normalizedExisting != normalizedCanonical {
            book.subjects = canonical.isEmpty ? nil : canonical
        }
        try? modelContext.save()
    }

    private func applySubjectSelection() {
        guard let profile else { return }
        let canonical = profile.registerSubjects(selectedSubjects)
        selectedSubjects = canonical
        book.subjects = canonical.isEmpty ? nil : canonical
        try? modelContext.save()
    }

    private func ensureBookStatsSection() {
        guard let profile else { return }
        if !profile.bookDetailSectionOrder.contains(BookDetailSection.bookStats.rawValue) {
            if let descriptionIndex = profile.bookDetailSectionOrder.firstIndex(of: BookDetailSection.description.rawValue) {
                profile.bookDetailSectionOrder.insert(BookDetailSection.bookStats.rawValue, at: descriptionIndex + 1)
            } else {
                profile.bookDetailSectionOrder.insert(BookDetailSection.bookStats.rawValue, at: 0)
            }
            profile.showBookStats = true
            try? modelContext.save()
        }
    }

    private var heroActions: some View {
        HStack(spacing: 24) {
            heroPlayButton
            heroStatusButton
        }
        .padding(.top, 4)
    }

    private var heroPlayButton: some View {
        Button {
            Haptics.impact(.light)
            showLogSession = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeColor.color.gradient)
                        .shadow(color: themeColor.color.opacity(0.4), radius: 10, y: 6)

                    Circle()
                        .strokeBorder(themeColor.color.opacity(0.3), lineWidth: 1)

                    Image(systemName: "play.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(themeColor.onColor(for: colorScheme))

                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.7),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(20))
                    .offset(x: playShimmer)
                    .mask(
                        Circle()
                            .scale(0.9)
                    )
                    .blendMode(.screen)
                }
                .frame(width: 54, height: 54)

                Text("Log Session")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            playShimmer = -50
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                playShimmer = 50
            }
        }
    }

    private var heroStatusButton: some View {
        Menu {
            ForEach(ReadingStatus.allCases, id: \.self) { status in
                Button {
                    handleStatusChange(to: status)
                } label: {
                    Label {
                        Text(status.displayNameKey)
                    } icon: {
                        Image(systemName: status.icon)
                        if book.readingStatus == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.secondaryBackground)
                        .overlay(
                            Circle()
                                .strokeBorder(themeColor.color.opacity(0.2), lineWidth: 1)
                        )

                    Image(systemName: book.readingStatus.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(themeColor.color)
                }
                .frame(width: 54, height: 54)

                Text(book.readingStatus.shortNameKey)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
            }
        }
        .buttonStyle(.plain)
        .transaction { $0.animation = nil }
    }

    // MARK: - Description Section

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "text.alignleft")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("About")
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func emptySectionCard(
        icon: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        InlineEmptyStateView(
            icon: icon,
            title: title,
            message: message,
            actionTitle: actionTitle,
            action: action
        )
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Last Position Section

    private func lastPositionSection(_ lastPos: BookPosition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Last Position")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(lastPos.positionDescription)
                    .font(.subheadline.weight(.medium))

                if let note = lastPos.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(lastPos.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Quotes Section

    private func quotesSection(_ quotes: [Quote]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                        .font(.caption)
                        .foregroundStyle(themeColor.color)
                        .frame(width: 16)

                    Text("Quotes")
                        .font(.headline)
                }

                Spacer()

                Button {
                    showAddQuote = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(themeColor.color)
                }
            }

            VStack(spacing: 10) {
                ForEach(quotes.sorted(by: { $0.dateAdded > $1.dateAdded })) { quote in
                    NavigationLink {
                        QuoteDetailView(quote: quote, book: book)
                    } label: {
                        QuoteRow(quote: quote)
                    }
                    .buttonStyle(.plain)

                    if quote.id != quotes.sorted(by: { $0.dateAdded > $1.dateAdded }).last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Reading History Section

    @State private var showAllSessions = false
    private var historyRowHeight: CGFloat { 64 }

    private func historyListHeight(_ count: Int) -> CGFloat {
        CGFloat(count) * historyRowHeight
    }

    private var readingHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("History")
                    .font(.headline)
            }

            let hideAuto = profile?.hideAutoSessionsIPhone ?? false
            let sessions = (book.readingSessions ?? [])
                .filter { session in
                    hideAuto ? !session.isAutoGenerated : true
                }
                .sorted(by: { $0.startDate > $1.startDate })

            let displayedSessions = showAllSessions ? sessions : Array(sessions.prefix(5))

            VStack(spacing: 10) {
                List {
                    ForEach(displayedSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session, book: book)
                        } label: {
                            ReadingSessionRow(session: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                                showDeleteSessionAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                sessionToDelete = session
                                showDeleteSessionAlert = true
                            } label: {
                                Label("Delete Session", systemImage: "trash")
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .environment(\.defaultMinListRowHeight, historyRowHeight)
                .frame(height: historyListHeight(displayedSessions.count))

                if sessions.count > 5 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAllSessions.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(
                                showAllSessions
                                ? localized("Show Less", locale: locale)
                                : String.localizedStringWithFormat(
                                    localized("Show All (%lld)", locale: locale),
                                    sessions.count
                                )
                            )
                                .font(.caption.weight(.semibold))
                            Image(systemName: showAllSessions ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(themeColor.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(themeColor.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Notes")
                    .font(.headline)
            }

            Text(book.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Subjects Section

    @State private var showAllSubjects = false

    private func subjectsSection(_ subjects: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text("Subjects")
                    .font(.headline)

                Spacer()

                Button {
                    selectedSubjects = subjects
                    showSubjectPicker = true
                } label: {
                    Text("Edit")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(themeColor.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeColor.color.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            let displayedSubjects = showAllSubjects ? subjects : Array(subjects.prefix(6))

            FlowLayout(spacing: 8) {
                ForEach(displayedSubjects, id: \.self) { subject in
                    Text(subject)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeColor.color.opacity(0.1), in: Capsule())
                        .foregroundStyle(themeColor.color)
                }
            }

            if subjects.count > 6 {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showAllSubjects.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(
                            showAllSubjects
                            ? localized("Show Less", locale: locale)
                            : String.localizedStringWithFormat(
                                localized("Show All (%lld)", locale: locale),
                                subjects.count
                            )
                        )
                            .font(.caption.weight(.semibold))
                        Image(systemName: showAllSubjects ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundStyle(themeColor.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeColor.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Metadata Section

    @ViewBuilder
    private var metadataSection: some View {
        let hasAnyVisibleMetadata = (book.publisher != nil && (profile?.showPublisher ?? true)) ||
                                   (book.publishedDate != nil && (profile?.showPublishedDate ?? true)) ||
                                   (book.language != nil && (profile?.showLanguage ?? true)) ||
                                   (book.isbn != nil && (profile?.showISBN ?? true))

        if hasAnyVisibleMetadata {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(themeColor.color)
                        .frame(width: 16)

                    Text(localized("Details", locale: locale))
                        .font(.headline)
                }

                VStack(spacing: 10) {
                    if let publisher = book.publisher, profile?.showPublisher ?? true {
                        metadataRow(icon: "building.2.fill", label: localized("Publisher", locale: locale), value: publisher)
                    }

                    if let publishedDate = book.publishedDate, profile?.showPublishedDate ?? true {
                        metadataRow(icon: "calendar", label: localized("Published Date", locale: locale), value: publishedDate)
                    }

                    if let language = book.language, profile?.showLanguage ?? true {
                        metadataRow(icon: "globe", label: localized("Language", locale: locale), value: language)
                    }

                    if let isbn = book.isbn, profile?.showISBN ?? true {
                        metadataRow(icon: "barcode", label: localized("ISBN", locale: locale), value: isbn)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func markAsFinished() {
        handleStatusChange(to: .finished)
    }

    private func handleStatusChange(to status: ReadingStatus) {
        if book.readingStatus == status { return }

        if status == .finished {
            if !hasTrackedSessions {
                showFinishOptions = true
                return
            }
            updateReadingStatus(to: .finished)
            return
        }

        // If leaving Currently Reading with progress, show alert to confirm
        if book.readingStatus == .currentlyReading && book.currentPage > 0 {
            savedProgress = book.currentPage
            pendingStatus = status
            showStatusChangeAlert = true
        } else {
            updateReadingStatus(to: status)
        }
    }

    private func updateReadingStatus(to status: ReadingStatus) {
        let oldStatus = book.readingStatus
        let sessions = book.readingSessions ?? []
        let hasTrackedSessions = sessions.contains { $0.countsTowardStats }
        let hasAnySessions = !sessions.isEmpty

        Haptics.selection()
        withAnimation(Theme.Animation.smooth) {
            if status == .finished {
                showConfetti = true
            }
            // STEP 1: Save progress when leaving Currently Reading
            if oldStatus == .currentlyReading && book.currentPage > 0 {
                book.savedCurrentPage = book.currentPage
            }

            // STEP 2: Update status
            book.readingStatus = status

            // STEP 3: Handle progress and dates based on NEW status
            switch status {
            case .currentlyReading:
                // Set start date if first time reading
                if book.dateStarted == nil {
                    book.dateStarted = Date()
                }

                // Restore saved progress if available
                if let saved = book.savedCurrentPage {
                    book.currentPage = saved
                    book.savedCurrentPage = nil // Clear after use
                } else if let temp = savedProgress {
                    // Fallback to temporary saved progress
                    book.currentPage = temp
                }

            case .finished:
                // Save current progress before forcing to total
                if book.currentPage > 0 {
                    book.savedCurrentPage = book.currentPage
                }
                // Set to total pages if available
                if let totalPages = book.totalPages {
                    book.currentPage = totalPages
                }
                let finishedDate = Date()
                book.dateFinished = finishedDate

                if !hasAnySessions, book.currentPage > 0 {
                    let session = ReadingSession(
                        startDate: finishedDate,
                        endDate: finishedDate,
                        startPage: 0,
                        endPage: book.currentPage,
                        durationMinutes: 0,
                        xpEarned: 0,
                        isAutoGenerated: false,
                        countsTowardStats: false,
                        isImported: true,
                        book: book
                    )
                    modelContext.insert(session)
                }

            case .didNotFinish:
                // Save current progress
                if book.currentPage > 0 {
                    book.savedCurrentPage = book.currentPage
                }
                book.dateFinished = Date()

            case .wantToRead:
                // Only preserve progress if it came from real sessions
                if oldStatus == .currentlyReading && book.currentPage > 0 {
                    book.savedCurrentPage = book.currentPage
                } else if !hasTrackedSessions {
                    book.savedCurrentPage = nil
                }
                // Reset to 0 for Want to Read
                book.currentPage = 0
            }
        }

        // Clear temporary saved progress after use
        savedProgress = nil

        // Sync status change to Watch
        Task { @MainActor in
            await WatchConnectivityManager.shared.syncBooksToWatch()
        }
    }

    private func handleProgressSave(pagesRead: Int) {
        let session = ReadingSession(
            endDate: Date(),
            startPage: book.currentPage - pagesRead,
            endPage: book.currentPage,
            durationMinutes: pagesRead * 2,
            xpEarned: 0,
            isAutoGenerated: true,
            book: book
        )

        let engine = GamificationEngine(modelContext: modelContext)
        session.xpEarned = engine.calculateXP(for: session)
        modelContext.insert(session)

        if let profile = profiles.first {
            if !session.xpAwarded {
                engine.awardXP(session.xpEarned, to: profile)
                session.xpAwarded = true
            }
            engine.updateStreak(for: profile, sessionDate: Date())
            engine.checkAchievements(for: profile)
        }

        WidgetDataExporter.exportSnapshot(modelContext: modelContext)

        // Send targeted updates to Watch instead of full sync
        if let profile = profiles.first {
            WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
        }

        // NOTE: Page delta already sent by QuickProgressStepper/ProgressSliderView
        // Don't send it again here to avoid double application on Watch
    }

    private func deleteBook() {
        modelContext.delete(book)

        do {
            try modelContext.save()
        } catch {
            #if DEBUG
            print("Failed to delete book: \(error.localizedDescription)")
            #else
            AppLogger.logError(error, context: "Delete book", logger: AppLogger.database)
            #endif
            return
        }

        if let profile = profile {
            let engine = GamificationEngine(modelContext: modelContext)
            engine.recalculateStats(for: profile)
        }

        Task {
            await WatchConnectivityManager.shared.syncBooksToWatch()
            if let profile = profile {
                WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
            }
        }

        WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        dismiss()
    }

    private func deleteSession(_ session: ReadingSession) {
        do {
            try SessionManager.deleteSession(session, in: modelContext)
        } catch {
            #if DEBUG
            print("Failed to delete session: \(error.localizedDescription)")
            #else
            AppLogger.logError(error, context: "Delete session", logger: AppLogger.database)
            #endif
        }
    }
}

// MARK: - Finish Book Log

struct FinishBookLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    let book: Book
    let onFinish: () -> Void

    @State private var endPage: Int
    @State private var endPageText: String
    @State private var durationMinutes = 60
    @State private var lastDurationMinutes = 60
    @State private var finishDate = Date()
    @State private var includeDuration = false
    @State private var useStartDate = false
    @State private var startDate = Date()
    @FocusState private var focusedField: FocusField?

    enum FocusField: Hashable {
        case endPage
    }

    init(book: Book, onFinish: @escaping () -> Void) {
        self.book = book
        self.onFinish = onFinish
        let totalPages = book.totalPages ?? 0
        let defaultEndPage = totalPages > 0 ? totalPages : max(0, book.currentPage)
        _endPage = State(initialValue: defaultEndPage)
        _endPageText = State(initialValue: defaultEndPage > 0 ? "\(defaultEndPage)" : "")
        let now = Date()
        _finishDate = State(initialValue: now)
        _useStartDate = State(initialValue: book.dateStarted != nil)
        _startDate = State(initialValue: book.dateStarted ?? now)
    }

    private var pagesRead: Int {
        max(0, endPage)
    }

    private var estimatedXP: Int {
        let engine = GamificationEngine(modelContext: modelContext)
        let mockSession = ReadingSession(
            startPage: 0,
            endPage: endPage,
            durationMinutes: includeDuration ? durationMinutes : 0
        )
        return engine.calculateXP(for: mockSession)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("Reading Progress", locale: locale)) {
                    HStack {
                        Text(localized("From Page", locale: locale))
                        Spacer()
                        Text(verbatim: "0")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }

                    HStack {
                        Text(localized("To Page", locale: locale))
                        Spacer()
                        TextField("0", text: $endPageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .focused($focusedField, equals: .endPage)
                            .onChange(of: endPageText) { _, newValue in
                                handleEndPageInput(newValue)
                            }

                        if let totalPages = book.totalPages, totalPages > 0 {
                            Text(
                                String.localizedStringWithFormat(
                                    localized("/ %lld", locale: locale),
                                    totalPages
                                )
                            )
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Image(systemName: "book.pages")
                            .foregroundStyle(themeColor.color)

                        Text(localized("Pages Read", locale: locale))
                        Spacer()
                        Text(pagesRead, format: .number)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(themeColor.color)
                    }
                }

                Section(localized("Dates", locale: locale)) {
                    DatePicker(
                        localized("Finished on", locale: locale),
                        selection: $finishDate,
                        in: (useStartDate ? startDate : Date.distantPast)...Date(),
                        displayedComponents: [.date]
                    )

                    Toggle(localized("Add start date", locale: locale), isOn: $useStartDate)
                        .onChange(of: useStartDate) { _, newValue in
                            if newValue, startDate > finishDate {
                                startDate = finishDate
                            }
                        }

                    if useStartDate {
                        DatePicker(
                            localized("Started on", locale: locale),
                            selection: $startDate,
                            in: ...finishDate,
                            displayedComponents: [.date]
                        )
                    }

                    Text(localized("Dates track your reading window. Time spent is separate.", locale: locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section(localized("Time Spent", locale: locale)) {
                    Toggle(localized("Track time spent", locale: locale), isOn: $includeDuration)
                        .onChange(of: includeDuration) { _, newValue in
                            if newValue {
                                durationMinutes = max(1, lastDurationMinutes)
                            } else {
                                lastDurationMinutes = max(1, durationMinutes)
                                durationMinutes = 0
                            }
                        }

                    if includeDuration {
                        DurationPickerView(minutes: $durationMinutes, maxHours: 99)
                    } else {
                        Text(localized("This finish will count pages only.", locale: locale))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.Colors.xpGradient)

                        Text("Estimated XP")
                        Spacer()
                        Text(verbatim: "+\(estimatedXP)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.xpGradient)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if !includeDuration {
                    durationMinutes = 0
                }
                syncEndPageText(with: endPage)
            }
            .onChange(of: finishDate) { _, newValue in
                if useStartDate, newValue < startDate {
                    startDate = newValue
                }
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == nil {
                    syncEndPageText(with: endPage)
                }
            }
            .navigationTitle("Log Finish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveFinish()
                    }
                    .disabled(pagesRead <= 0)
                }

                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        hideKeyboard()
                    }
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func handleEndPageInput(_ input: String) {
        let filtered = input.filter { $0.isNumber }
        if filtered != input {
            endPageText = filtered
            return
        }

        if filtered.isEmpty {
            endPage = 0
            return
        }

        guard let newValue = Int(filtered) else { return }
        let clampedValue = clampEndPage(newValue)

        if clampedValue != newValue {
            endPageText = "\(clampedValue)"
        }

        endPage = clampedValue
    }

    private func clampEndPage(_ value: Int) -> Int {
        if let maxPages = book.totalPages, maxPages > 0 {
            return min(value, maxPages)
        }
        return max(0, value)
    }

    private func syncEndPageText(with value: Int) {
        guard focusedField != .endPage else { return }
        let textValue = value > 0 ? "\(value)" : ""
        if endPageText != textValue {
            endPageText = textValue
        }
    }

    private func saveFinish() {
        Haptics.impact(.medium)
        if let activeSession = activeSessions.first {
            let endedId = activeSession.id
            modelContext.delete(activeSession)
            WatchConnectivityManager.shared.sendActiveSessionEndToWatch(activeSessionId: endedId)
            Task {
                await ReadingSessionActivityManager.shared.endActivity()
            }
        }

        let endDate = finishDate
        let sessionStartDate = finishDate
        let durationToSave = includeDuration ? durationMinutes : 0

        let session = ReadingSession(
            startDate: sessionStartDate,
            endDate: endDate,
            startPage: 0,
            endPage: endPage,
            durationMinutes: durationToSave,
            book: book
        )

        let engine = GamificationEngine(modelContext: modelContext)
        session.xpEarned = engine.calculateXP(for: session)
        modelContext.insert(session)

        let previousPage = book.currentPage
        if let totalPages = book.totalPages, totalPages > 0 {
            book.currentPage = totalPages
        } else {
            book.currentPage = max(0, endPage)
        }
        book.readingStatus = .finished
        book.dateFinished = finishDate
        if useStartDate {
            book.dateStarted = sessionStartDate
        }
        book.savedCurrentPage = nil

        let pageDelta = book.currentPage - previousPage
        if pageDelta != 0 {
            WatchConnectivityManager.shared.sendPageDeltaToWatch(
                bookUUID: book.id,
                delta: pageDelta,
                newPage: book.currentPage
            )
        }

        if let profile = profiles.first {
            if !session.xpAwarded {
                engine.awardXP(session.xpEarned, to: profile)
                session.xpAwarded = true
            }
            engine.updateStreak(for: profile, sessionDate: finishDate)
            engine.checkAchievements(for: profile)
            WatchConnectivityManager.shared.sendProfileStatsToWatch(profile)
        }

        Task {
            WatchConnectivityManager.shared.sendSessionToWatch(session)
            await WatchConnectivityManager.shared.syncBooksToWatch()
        }

        WidgetDataExporter.exportSnapshot(modelContext: modelContext)
        try? modelContext.save()
        onFinish()
        dismiss()
    }
}

// MARK: - Reading Session Row

struct ReadingSessionRow: View {
    @Environment(\.locale) private var locale
    let session: ReadingSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if session.isActive {
                        Text(
                            String.localizedStringWithFormat(
                                localized("Started at page %lld", locale: locale),
                                session.startPage
                            )
                        )
                            .font(.subheadline.weight(.medium))
                    } else {
                        Text(
                            String.localizedStringWithFormat(
                                localized("From page %lld to page %lld", locale: locale),
                                session.startPage,
                                session.endPage
                            )
                        )
                            .font(.subheadline.weight(.medium))
                    }

                    if session.isImported || !session.countsTowardStats {
                        Text(localized("Imported", locale: locale))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }

                HStack(spacing: 4) {
                    Text(session.pagesRead >= 0 ? "+\(session.pagesRead)" : "\(session.pagesRead)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(verbatim: "•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(session.startDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(verbatim: "•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(
                        String.localizedStringWithFormat(
                            localized("%lld min", locale: locale),
                            session.durationMinutes
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(
                String.localizedStringWithFormat(
                    localized("%lld XP", locale: locale),
                    session.xpEarned
                )
            )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimation: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    scale = 1.8
                }
            }
    }
}

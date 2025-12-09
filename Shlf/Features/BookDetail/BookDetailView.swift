//
//  BookDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import OSLog
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    @State private var showLogSession = false
    @State private var showEditBook = false
    @State private var showDeleteAlert = false
    @State private var showConfetti = false
    @State private var showAddQuote = false
    @State private var showStatusChangeAlert = false
    @State private var pendingStatus: ReadingStatus?
    @State private var savedProgress: Int?

    private var profile: UserProfile? {
        profiles.first
    }

    private var hasActiveSession: Bool {
        activeSessions.first != nil
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

                        // Compact stats overview
                        statsOverview

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
                            showLogSession = true
                        } label: {
                            Label("Log Session", systemImage: "clock.badge.checkmark")
                        }

                        Button {
                            markAsFinished()
                        } label: {
                            Label("Mark Finished", systemImage: "checkmark.circle")
                        }

                        Button {
                            book.readingStatus = .didNotFinish
                            book.dateFinished = Date()

                            // Sync status change to Watch
                            Task { @MainActor in
                                await WatchConnectivityManager.shared.syncBooksToWatch()
                            }
                        } label: {
                            Label("Mark as DNF", systemImage: "xmark.circle")
                        }

                        Divider()
                    }

                    if book.readingStatus == .currentlyReading {
                        Button {
                            showAddQuote = true
                        } label: {
                            Label("Add Quote", systemImage: "quote.bubble")
                        }

                        Divider()
                    }

                    Button {
                        showEditBook = true
                    } label: {
                        Label("Edit Book", systemImage: "pencil.line")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Book", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
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
        .sheet(isPresented: $showAddQuote) {
            AddQuoteView(book: book)
        }
        .alert("Delete Book?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteBook()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(book.title) and all reading sessions.")
        }
        .alert("Change Reading Status?", isPresented: $showStatusChangeAlert) {
            Button("Change Status", role: .destructive) {
                if let status = pendingStatus {
                    updateReadingStatus(to: status)
                }
                pendingStatus = nil
            }
            Button("Cancel", role: .cancel) {
                pendingStatus = nil
            }
        } message: {
            if let status = pendingStatus {
                Text("You're on page \(book.currentPage). Changing to \"\(status.rawValue)\" will reset your progress, but it will be saved and restored if you switch back to \"Currently Reading\".")
            }
        }
    }

    // MARK: - Section Rendering

    @ViewBuilder
    private func sectionView(for section: BookDetailSection) -> some View {
        // Check if section should be visible
        if profile?.isBookDetailSectionVisible(section) ?? true {
            switch section {
            case .description:
                if let description = book.bookDescription {
                    descriptionSection(description)
                }

            case .lastPosition:
                if let lastPos = book.lastPosition {
                    lastPositionSection(lastPos)
                }

            case .quotes:
                if let quotes = book.quotes, !quotes.isEmpty {
                    quotesSection(quotes)
                }

            case .notes:
                if !book.notes.isEmpty {
                    notesSection
                }

            case .subjects:
                if let subjects = book.subjects, !subjects.isEmpty {
                    subjectsSection(subjects)
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

            // Compact status pill
            Menu {
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Button {
                        handleStatusChange(to: status)
                    } label: {
                        Label {
                            Text(status.rawValue)
                        } icon: {
                            Image(systemName: status.icon)
                            if book.readingStatus == status {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: book.readingStatus.icon)
                        .font(.caption.weight(.semibold))

                    Text(book.readingStatus.shortName)
                        .font(.caption.weight(.semibold))

                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption2)
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(themeColor.color.gradient)
                        .shadow(color: themeColor.color.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }

            // Type badge
            if book.bookType != .physical {
                HStack(spacing: 4) {
                    Image(systemName: book.bookType.icon)
                        .font(.caption2)
                    Text(book.bookType.rawValue)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(Theme.Colors.tertiaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 16)
    }

    // MARK: - Active Session Banner

    private var activeSessionBanner: some View {
        Button {
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
                        Text("Active Session")
                            .font(.subheadline.weight(.semibold))

                        Text("\(activeSession.sourceDevice) • Started at page \(activeSession.currentPage)")
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

    // MARK: - Stats Overview

    private var statsOverview: some View {
        Group {
            if book.totalPages != nil {
                EmptyView()
            }
        }
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
                ForEach(displayedSessions) { session in
                    ReadingSessionRow(session: session)

                    if session.id != displayedSessions.last?.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }

                if sessions.count > 5 {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showAllSessions.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showAllSessions ? "Show Less" : "Show All (\(sessions.count))")
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
                        Text(showAllSubjects ? "Show Less" : "Show All (\(subjects.count))")
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

                    Text("Details")
                        .font(.headline)
                }

                VStack(spacing: 10) {
                    if let publisher = book.publisher, profile?.showPublisher ?? true {
                        metadataRow(icon: "building.2.fill", label: "Publisher", value: publisher)
                    }

                    if let publishedDate = book.publishedDate, profile?.showPublishedDate ?? true {
                        metadataRow(icon: "calendar", label: "Published", value: publishedDate)
                    }

                    if let language = book.language, profile?.showLanguage ?? true {
                        metadataRow(icon: "globe", label: "Language", value: language)
                    }

                    if let isbn = book.isbn, profile?.showISBN ?? true {
                        metadataRow(icon: "barcode", label: "ISBN", value: isbn)
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
        book.readingStatus = .finished
        book.dateFinished = Date()
        if let totalPages = book.totalPages {
            book.currentPage = totalPages
        }
        showConfetti = true

        // Sync status change to Watch
        Task { @MainActor in
            await WatchConnectivityManager.shared.syncBooksToWatch()
        }
    }

    private func handleStatusChange(to status: ReadingStatus) {
        if book.readingStatus == status { return }

        if book.readingStatus == .currentlyReading && book.currentPage > 0 {
            savedProgress = book.currentPage
            pendingStatus = status
            showStatusChangeAlert = true
        } else {
            updateReadingStatus(to: status)
        }
    }

    private func updateReadingStatus(to status: ReadingStatus) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            book.readingStatus = status

            switch status {
            case .currentlyReading:
                if book.dateStarted == nil {
                    book.dateStarted = Date()
                }
                if let saved = savedProgress {
                    book.currentPage = saved
                }
            case .finished:
                book.dateFinished = Date()
                if let totalPages = book.totalPages {
                    book.currentPage = totalPages
                }
            case .didNotFinish:
                book.dateFinished = Date()
            case .wantToRead:
                break
            }
        }

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

        // Send the specific book delta instead of syncing all books
        WatchConnectivityManager.shared.sendPageDeltaToWatch(bookUUID: book.id, delta: pagesRead)
    }

    private func deleteBook() {
        modelContext.delete(book)

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete book: \(error.localizedDescription)")
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
}

// MARK: - Reading Session Row

struct ReadingSessionRow: View {
    let session: ReadingSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 4) {
                    Text(session.pagesRead >= 0 ? "+\(session.pagesRead)" : "\(session.pagesRead)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(session.startDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text("\(session.durationMinutes) min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text("\(session.xpEarned) XP")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
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

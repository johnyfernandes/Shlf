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
                            updateReadingStatus(to: .didNotFinish)
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
                        showShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showEditBook = true
                    } label: {
                        Label("Edit Book", systemImage: "pencil.line")
                    }

                    if canChangeEdition {
                        Button {
                            showChangeEdition = true
                        } label: {
                            Label("Change Edition", systemImage: "books.vertical")
                        }
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
        .sheet(isPresented: $showChangeEdition) {
            ChangeEditionView(book: book)
        }
        .sheet(isPresented: $showAddQuote) {
            AddQuoteView(book: book)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(book: book)
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
                Text("You're on page \(book.currentPage). Your progress will be saved and automatically restored when you return to \"Currently Reading\".")
            }
        }
        .alert("Delete Session?", isPresented: $showDeleteSessionAlert) {
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
                sessionToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                sessionToDelete = nil
            }
        } message: {
            Text("This removes the session and updates stats. If it was your latest session, your current page will roll back to the previous one.")
        }
        .confirmationDialog("Finish Book", isPresented: $showFinishOptions, titleVisibility: .visible) {
            Button("Finished Before Tracking") {
                updateReadingStatus(to: .finished)
            }
            Button("Count This Finish") {
                showFinishLog = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No tracked sessions yet. You can exclude this finish from stats, or log it now.")
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
                ZStack {
                    HStack(spacing: 6) {
                        Image(systemName: ReadingStatus.wantToRead.icon)
                            .font(.caption.weight(.semibold))
                            .frame(width: 14)

                        Text(ReadingStatus.wantToRead.shortNameKey)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)

                        Image(systemName: "chevron.down.circle.fill")
                            .font(.caption2)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .opacity(0)
                    .accessibilityHidden(true)

                    HStack(spacing: 6) {
                        Image(systemName: book.readingStatus.icon)
                            .font(.caption.weight(.semibold))
                            .frame(width: 14)

                        Text(book.readingStatus.shortNameKey)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)

                        Image(systemName: "chevron.down.circle.fill")
                            .font(.caption2)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(themeColor.color.gradient)
                        .shadow(color: themeColor.color.opacity(0.4), radius: 8, x: 0, y: 4)
                )
                .clipShape(Capsule())
                .contentShape(Capsule())
                .transaction { $0.animation = nil }
            }
            .buttonStyle(.plain)

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
                    Text(String.localizedStringWithFormat(String(localized: "Saved at page %lld"), saved))
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

    private var missingPagesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "number.circle")
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(String(localized: "Add total pages"))
                    .font(.headline)
            }

            Text(String(localized: "Add pages to track progress and sessions."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showEditBook = true
            } label: {
                Text(String(localized: "Add pages"))
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

        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
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

    private func deleteSession(_ session: ReadingSession) {
        do {
            try SessionManager.deleteSession(session, in: modelContext)
        } catch {
            print("Failed to delete session: \(error.localizedDescription)")
        }
    }
}

// MARK: - Finish Book Log

struct FinishBookLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
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
                Section("Reading Progress") {
                    HStack {
                        Text("From Page")
                        Spacer()
                        Text("0")
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }

                    HStack {
                        Text("To Page")
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
                            Text("/ \(totalPages)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Image(systemName: "book.pages")
                            .foregroundStyle(themeColor.color)

                        Text("Pages Read")
                        Spacer()
                        Text("\(pagesRead)")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(themeColor.color)
                    }
                }

                Section("Dates") {
                    DatePicker(
                        "Finished on",
                        selection: $finishDate,
                        in: (useStartDate ? startDate : Date.distantPast)...Date(),
                        displayedComponents: [.date]
                    )

                    Toggle("Add start date", isOn: $useStartDate)
                        .onChange(of: useStartDate) { _, newValue in
                            if newValue, startDate > finishDate {
                                startDate = finishDate
                            }
                        }

                    if useStartDate {
                        DatePicker(
                            "Started on",
                            selection: $startDate,
                            in: ...finishDate,
                            displayedComponents: [.date]
                        )
                    }

                    Text("Dates track your reading window. Time spent is separate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Time Spent") {
                    Toggle("Track time spent", isOn: $includeDuration)
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
                        Text("This finish will count pages only.")
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
                        Text("+\(estimatedXP)")
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
    let session: ReadingSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(session.displayName)
                        .font(.subheadline.weight(.medium))

                    if session.isImported || !session.countsTowardStats {
                        Text("Imported")
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

//
//  BookDetailView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]

    @State private var showLogSession = false
    @State private var showEditBook = false
    @State private var showDeleteAlert = false
    @State private var showConfetti = false

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                bookHeader

                if book.readingStatus == .currentlyReading {
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
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    } else {
                        QuickProgressStepper(
                            book: book,
                            incrementAmount: profile?.pageIncrementAmount ?? 1,
                            showConfetti: $showConfetti,
                            onSave: { pagesRead in
                                handleProgressSave(pagesRead: pagesRead)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }

                if let description = book.bookDescription, profile?.showDescription ?? true {
                    descriptionSection(description)
                }

                if profile?.showMetadata ?? true {
                    metadataSection
                }

                if book.readingStatus == .currentlyReading {
                    progressSection
                }

                if let subjects = book.subjects, !subjects.isEmpty, profile?.showSubjects ?? true {
                    subjectsSection(subjects)
                }

                if !book.readingSessions.isEmpty, profile?.showReadingHistory ?? true {
                    readingHistorySection
                }

                if !book.notes.isEmpty, profile?.showNotes ?? true {
                    notesSection
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .confetti(isActive: $showConfetti)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if book.readingStatus == .currentlyReading {
                        Button {
                            showLogSession = true
                        } label: {
                            Label("Log Reading Session", systemImage: "plus.circle")
                        }

                        Button {
                            markAsFinished()
                        } label: {
                            Label("Mark Finished", systemImage: "checkmark.circle")
                        }

                        Button {
                            book.readingStatus = .didNotFinish
                        } label: {
                            Label("Mark as DNF", systemImage: "xmark.circle")
                        }

                        Divider()
                    }

                    Button {
                        showEditBook = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showLogSession) {
            LogReadingSessionView(book: book)
        }
        .sheet(isPresented: $showEditBook) {
            EditBookView(book: book)
        }
        .alert("Delete Book?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteBook()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(book.title) and all reading sessions.")
        }
    }

    private var bookHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 140,
                height: 210
            )

            VStack(spacing: Theme.Spacing.xs) {
                Text(book.title)
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.text)
                    .multilineTextAlignment(.center)

                Text(book.author)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)

                HStack(spacing: Theme.Spacing.sm) {
                    Label(book.bookType.rawValue, systemImage: book.bookType.icon)
                    Text("•")

                    Menu {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Button {
                                updateReadingStatus(to: status)
                            } label: {
                                Label(status.rawValue, systemImage: status.icon)
                            }
                        }
                    } label: {
                        Label(book.readingStatus.rawValue, systemImage: book.readingStatus.icon)
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Progress")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            if let totalPages = book.totalPages {
                VStack(spacing: Theme.Spacing.sm) {
                    HStack {
                        Text("\(book.currentPage)")
                            .font(Theme.Typography.title)

                        Text("/ \(totalPages) pages")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text("\(Int(book.progressPercentage))%")
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.primary)
                    }

                    ProgressView(value: book.progressPercentage, total: 100)
                        .tint(Theme.Colors.primary)
                }
                .padding(Theme.Spacing.md)
                .cardStyle()
            } else {
                Text("Total pages not set")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.md)
                    .cardStyle()
            }
        }
    }

    private var readingHistorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Reading History")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            let sessions = book.readingSessions.sorted { $0.startDate > $1.startDate }

            ForEach(sessions) { session in
                ReadingSessionRow(session: session)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Notes")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            Text(book.notes)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
        }
    }

    @ViewBuilder
    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("About This Book")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            Text(description)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .lineLimit(5)
                .padding(Theme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
        }
    }

    @ViewBuilder
    private var metadataSection: some View {
        let hasAnyVisibleMetadata = (book.publisher != nil && (profile?.showPublisher ?? true)) ||
                                   (book.publishedDate != nil && (profile?.showPublishedDate ?? true)) ||
                                   (book.language != nil && (profile?.showLanguage ?? true)) ||
                                   (book.isbn != nil && (profile?.showISBN ?? true)) ||
                                   (book.totalPages != nil && (profile?.showReadingTime ?? true))

        if hasAnyVisibleMetadata {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Details")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.text)

                VStack(spacing: Theme.Spacing.xs) {
                    if let publisher = book.publisher, profile?.showPublisher ?? true {
                        MetadataRow(label: "Publisher", value: publisher, icon: "building.2")
                    }

                    if let publishedDate = book.publishedDate, profile?.showPublishedDate ?? true {
                        MetadataRow(label: "Published", value: publishedDate, icon: "calendar")
                    }

                    if let language = book.language, profile?.showLanguage ?? true {
                        MetadataRow(label: "Language", value: language, icon: "globe")
                    }

                    if let isbn = book.isbn, profile?.showISBN ?? true {
                        MetadataRow(label: "ISBN", value: isbn, icon: "barcode")
                    }

                    if let totalPages = book.totalPages, profile?.showReadingTime ?? true {
                        let readingTime = estimateReadingTime(pages: totalPages)
                        MetadataRow(label: "Reading Time", value: readingTime, icon: "clock")
                    }
                }
                .padding(Theme.Spacing.md)
                .cardStyle()
            }
        }
    }

    @ViewBuilder
    private func subjectsSection(_ subjects: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Genres & Topics")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            FlowLayout(spacing: Theme.Spacing.xs) {
                ForEach(subjects.prefix(10), id: \.self) { subject in
                    Text(subject)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(Theme.Spacing.md)
            .cardStyle()
        }
    }

    private func estimateReadingTime(pages: Int) -> String {
        let minutesPerPage = 2.0
        let totalMinutes = Double(pages) * minutesPerPage
        let hours = Int(totalMinutes / 60)

        if hours < 1 {
            return "\(Int(totalMinutes)) min"
        } else if hours < 24 {
            return "~\(hours) hours"
        } else {
            let days = hours / 24
            return "~\(days) days"
        }
    }

    private func updateReadingStatus(to status: ReadingStatus) {
        let previousStatus = book.readingStatus
        book.readingStatus = status

        switch status {
        case .currentlyReading:
            if book.dateStarted == nil {
                book.dateStarted = Date()
            }
        case .finished:
            book.dateFinished = Date()
            if let totalPages = book.totalPages {
                book.currentPage = totalPages
            }
            // Update goals when finishing a book
            if let profile = profile {
                let tracker = GoalTracker(modelContext: modelContext)
                tracker.updateGoals(for: profile)
            }
        case .wantToRead:
            // Reset progress if moving back to want to read
            if previousStatus != .wantToRead {
                book.currentPage = 0
                book.dateStarted = nil
                book.dateFinished = nil
            }
        case .didNotFinish:
            if book.dateFinished == nil {
                book.dateFinished = Date()
            }
        }
    }

    private func markAsFinished() {
        updateReadingStatus(to: .finished)
    }

    private func handleProgressSave(pagesRead: Int) {
        // Create a mini reading session to track progress for goals
        guard pagesRead > 0, let profile = profile else { return }

        let endPage = book.currentPage
        let startPage = max(0, endPage - pagesRead)

        let session = ReadingSession(
            startPage: startPage,
            endPage: endPage,
            durationMinutes: 0, // We don't track time for quick updates
            xpEarned: 0,
            book: book
        )

        modelContext.insert(session)

        // Update goals
        let tracker = GoalTracker(modelContext: modelContext)
        tracker.updateGoals(for: profile)
    }

    private func deleteBook() {
        modelContext.delete(book)
        dismiss()
    }
}

struct ReadingSessionRow: View {
    let session: ReadingSession

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(session.startDate, style: .date)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)

                Text(session.startDate, style: .time)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "book.pages")
                        .font(.caption)

                    Text("\(session.pagesRead) pages")
                        .font(Theme.Typography.callout)
                }
                .foregroundStyle(Theme.Colors.text)

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(.caption)

                    Text("\(session.durationMinutes) min")
                        .font(Theme.Typography.caption)
                }
                .foregroundStyle(Theme.Colors.secondaryText)

                if session.xpEarned > 0 {
                    HStack(spacing: Theme.Spacing.xxs) {
                        Image(systemName: "star.fill")
                            .font(.caption2)

                        Text("+\(session.xpEarned) XP")
                            .font(Theme.Typography.caption2)
                    }
                    .foregroundStyle(Theme.Colors.xpGradient)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

struct MetadataRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
                .frame(width: 20)

            Text(label)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.secondaryText)

            Spacer()

            Text(value)
                .font(Theme.Typography.callout)
                .foregroundStyle(Theme.Colors.text)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size = CGSize.zero
        var frames = [CGRect]()

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            totalPages: 180,
            currentPage: 45,
            readingStatus: .currentlyReading,
            bookDescription: "A classic novel set in the Jazz Age, exploring themes of wealth, love, and the American Dream.",
            subjects: ["Fiction", "Classic Literature", "Romance", "American Literature"],
            publisher: "Scribner",
            publishedDate: "1925",
            language: "EN"
        ))
    }
    .modelContainer(for: [Book.self, ReadingSession.self], inMemory: true)
}

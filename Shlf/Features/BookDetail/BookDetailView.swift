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

    @State private var showLogSession = false
    @State private var showEditBook = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                bookHeader

                if book.readingStatus == .currentlyReading {
                    quickActions
                }

                progressSection

                if !book.readingSessions.isEmpty {
                    readingHistorySection
                }

                if !book.notes.isEmpty {
                    notesSection
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
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
                    Label(book.readingStatus.rawValue, systemImage: book.readingStatus.icon)
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                showLogSession = true
            } label: {
                Label("Log Reading Session", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .primaryButton()
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    markAsFinished()
                } label: {
                    Label("Mark Finished", systemImage: "checkmark.circle")
                        .font(Theme.Typography.callout)
                        .frame(maxWidth: .infinity)
                        .secondaryButton()
                }

                Button {
                    book.readingStatus = .didNotFinish
                } label: {
                    Label("DNF", systemImage: "xmark.circle")
                        .font(Theme.Typography.callout)
                        .frame(maxWidth: .infinity)
                        .secondaryButton()
                }
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

    private func markAsFinished() {
        book.readingStatus = .finished
        book.dateFinished = Date()

        if let totalPages = book.totalPages {
            book.currentPage = totalPages
        }
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

#Preview {
    NavigationStack {
        BookDetailView(book: Book(
            title: "The Great Gatsby",
            author: "F. Scott Fitzgerald",
            totalPages: 180,
            currentPage: 45,
            readingStatus: .currentlyReading
        ))
    }
    .modelContainer(for: [Book.self, ReadingSession.self], inMemory: true)
}

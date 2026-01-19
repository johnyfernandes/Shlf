//
//  ChangeEditionView.swift
//  Shlf
//
//  Created by Codex on 03/02/2026.
//

import SwiftUI
import SwiftData

struct ChangeEditionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var book: Book

    @State private var editions: [EditionInfo] = []
    @State private var isLoading = false
    @State private var applyingEditionID: String?
    @State private var errorMessage: String?

    private let bookAPI = BookAPIService()

    var body: some View {
        NavigationStack {
            Group {
                if book.openLibraryWorkID == nil && book.openLibraryEditionID == nil && (book.isbn ?? "").isEmpty {
                    ContentUnavailableView {
                        Label("No Editions Available", systemImage: "books.vertical")
                    } description: {
                        Text("This book wasn’t added from Open Library.")
                    }
                } else if isLoading && editions.isEmpty {
                    ProgressView("Loading Editions...")
                        .tint(themeColor.color)
                } else if editions.isEmpty {
                    ContentUnavailableView {
                        Label("No Editions Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("Open Library didn’t return any editions for this book.")
                    }
                } else {
                    List(editions) { edition in
                        Button {
                            Task {
                                await applyEdition(edition)
                            }
                        } label: {
                            EditionRow(
                                edition: edition,
                                isCurrent: book.openLibraryEditionID == edition.olid,
                                isApplying: applyingEditionID == edition.olid
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(applyingEditionID != nil)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Change Edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(themeColor.color)
                }
            }
            .task {
                await loadEditions()
            }
            .alert("Couldn’t Change Edition", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func loadEditions() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        guard let workID = await resolveWorkIDIfNeeded() else { return }

        do {
            let fetched = try await bookAPI.fetchEditions(workID: workID)
            if fetched.isEmpty, let fallbackWorkID = await resolveWorkIDFromSearch(), fallbackWorkID != workID {
                editions = try await bookAPI.fetchEditions(workID: fallbackWorkID)
            } else {
                editions = fetched
            }
        } catch {
            errorMessage = "Open Library is unavailable right now. Please try again."
        }
    }

    private func applyEdition(_ edition: EditionInfo) async {
        guard applyingEditionID == nil else { return }
        applyingEditionID = edition.olid
        defer { applyingEditionID = nil }

        do {
            let fetched = try await bookAPI.fetchBookByOLID(olid: edition.olid)
            await MainActor.run {
                applyEditionData(fetched: fetched, edition: edition)
                try? modelContext.save()
                dismiss()
            }
        } catch {
            errorMessage = "Failed to load edition details. Please try again."
        }
    }

    private func resolveWorkIDIfNeeded() async -> String? {
        if let workID = book.openLibraryWorkID {
            return workID
        }

        do {
            if let editionID = book.openLibraryEditionID,
               let resolved = try await bookAPI.resolveWorkID(editionID: editionID) {
                book.openLibraryWorkID = resolved
                try? modelContext.save()
                return resolved
            }

            if let isbn = book.isbn,
               let resolved = try await bookAPI.resolveWorkID(isbn: isbn) {
                book.openLibraryWorkID = resolved
                try? modelContext.save()
                return resolved
            }
        } catch {
            errorMessage = "Open Library is unavailable right now. Please try again."
        }

        if let resolved = await resolveWorkIDFromSearch() {
            return resolved
        }

        return book.openLibraryWorkID
    }

    private func resolveWorkIDFromSearch() async -> String? {
        let trimmedTitle = book.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return nil }

        let authorPart = book.author.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = authorPart.isEmpty ? trimmedTitle : "\(trimmedTitle) \(authorPart)"

        do {
            let results = try await bookAPI.searchBooks(query: query)
            if let workID = results.first(where: { $0.workID != nil })?.workID {
                book.openLibraryWorkID = workID
                try? modelContext.save()
                return workID
            }
        } catch {
            errorMessage = "Open Library is unavailable right now. Please try again."
        }

        return nil
    }

    @MainActor
    private func applyEditionData(fetched: BookInfo, edition: EditionInfo) {
        let resolvedTitle = fetched.title.isEmpty ? edition.title : fetched.title
        let resolvedAuthor = fetched.author == "Unknown Author" ? book.author : fetched.author
        let resolvedSubjects = fetched.subjects?.isEmpty == false ? fetched.subjects : book.subjects

        let resolvedISBN = fetched.isbn ?? edition.isbn ?? book.isbn
        let resolvedCover = fetched.coverImageURL ?? edition.coverImageURL ?? book.coverImageURL
        let resolvedPages = fetched.totalPages ?? edition.numberOfPages ?? book.totalPages
        let resolvedPublisher = fetched.publisher ?? edition.publishers?.first ?? book.publisher
        let resolvedPublishedDate = fetched.publishedDate ?? edition.publishDate ?? book.publishedDate
        let resolvedLanguage = fetched.language ?? edition.language ?? book.language
        let resolvedDescription = fetched.description ?? book.bookDescription

        book.title = resolvedTitle
        book.author = resolvedAuthor
        book.isbn = resolvedISBN
        book.coverImageURL = resolvedCover
        book.totalPages = resolvedPages
        book.publisher = resolvedPublisher
        book.publishedDate = resolvedPublishedDate
        book.language = resolvedLanguage
        book.bookDescription = resolvedDescription
        book.subjects = resolvedSubjects
        book.openLibraryEditionID = edition.olid

        if let total = resolvedPages, total > 0, book.currentPage > total {
            book.currentPage = total
        }
    }
}

private struct EditionRow: View {
    @Environment(\.themeColor) private var themeColor
    let edition: EditionInfo
    let isCurrent: Bool
    let isApplying: Bool

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(
                imageURL: edition.coverImageURL,
                title: edition.title,
                width: 46,
                height: 70
            )
            .shadow(color: Theme.Shadow.small, radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(edition.title)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if let publishDate = edition.publishDate {
                        Text(publishDate)
                    }
                    if let pages = edition.numberOfPages {
                        Text("•")
                        Text("\(pages) pages")
                    }
                }
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)

                if let publisher = edition.publishers?.first {
                    Text(publisher)
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if isApplying {
                ProgressView()
                    .tint(themeColor.color)
            } else if isCurrent {
                Text("Current")
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(themeColor.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeColor.color.opacity(0.12), in: Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ChangeEditionView(book: Book(
        title: "Sample Book",
        author: "Sample Author",
        openLibraryWorkID: "OL123W",
        openLibraryEditionID: "OL456M"
    ))
    .modelContainer(for: [Book.self], inMemory: true)
}

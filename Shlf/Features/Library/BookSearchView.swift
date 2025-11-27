//
//  BookSearchView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct BookSearchView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (BookInfo) -> Void

    @State private var searchText = ""
    @State private var searchResults: [BookInfo] = []
    @State private var cachedResults: [BookInfo] = [] // Cache for client-side filtering
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var lastAPIQuery = ""
    @FocusState private var isSearchFocused: Bool

    private let bookAPI = BookAPIService()

    // Client-side filter results based on query
    private func filterResults(_ results: [BookInfo], query: String) -> [BookInfo] {
        let lowercaseQuery = query.lowercased()
        let filtered = results.filter { book in
            book.title.lowercased().contains(lowercaseQuery) ||
            book.author.lowercased().contains(lowercaseQuery) ||
            book.isbn?.lowercased().contains(lowercaseQuery) == true
        }

        // Prioritize books with cover images
        return sortByCovers(filtered)
    }

    // Sort results: books with covers first, then without
    private func sortByCovers(_ results: [BookInfo]) -> [BookInfo] {
        return results.sorted { book1, book2 in
            let hasCover1 = book1.coverImageURL != nil
            let hasCover2 = book2.coverImageURL != nil

            if hasCover1 && !hasCover2 {
                return true // book1 has cover, book2 doesn't - book1 comes first
            } else if !hasCover1 && hasCover2 {
                return false // book2 has cover, book1 doesn't - book2 comes first
            } else {
                return false // both have covers or both don't - keep original order
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchResults.isEmpty && !isSearching && !searchText.isEmpty {
                    ContentUnavailableView {
                        Label("No Results", systemImage: "magnifyingglass")
                    } description: {
                        Text("Try searching with a different title, author, or ISBN")
                    }
                } else if searchResults.isEmpty && !isSearching {
                    ContentUnavailableView {
                        Label("Search for Books", systemImage: "books.vertical")
                    } description: {
                        Text("Find books by title, author, or ISBN")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(Array(searchResults.enumerated()), id: \.offset) { index, bookInfo in
                                NavigationLink {
                                    BookPreviewView(bookInfo: bookInfo, onDismiss: {
                                        dismiss()
                                    })
                                } label: {
                                    BookSearchResultRow(bookInfo: bookInfo)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Search Books")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Title, author, or ISBN")
            .searchFocused($isSearchFocused)
            .onAppear {
                isSearchFocused = true
            }
            .onChange(of: searchText) { oldValue, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    await performSearch(query: newValue)
                }
            }
            .overlay {
                if isSearching {
                    VStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Spacer()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            await MainActor.run {
                searchResults = []
                cachedResults = []
                lastAPIQuery = ""
                isSearching = false
            }
            return
        }

        await MainActor.run {
            isSearching = true
        }

        // Debounce
        try? await Task.sleep(for: .milliseconds(400))

        guard !Task.isCancelled else {
            await MainActor.run {
                isSearching = false
            }
            return
        }

        do {
            let results = try await bookAPI.searchBooks(query: query)

            guard !Task.isCancelled else {
                // Don't touch cached results on cancellation
                await MainActor.run {
                    isSearching = false
                }
                return
            }

            await MainActor.run {
                // Cache results for client-side filtering, sorted by covers
                let sortedResults = sortByCovers(results)
                cachedResults = sortedResults
                searchResults = sortedResults
                lastAPIQuery = query
                isSearching = false
            }
        } catch is CancellationError {
            // Task was cancelled - keep existing cache
            await MainActor.run {
                isSearching = false
            }
        } catch {
            // Real error - keep cache but show current results
            print("Search error: \(error)")
            await MainActor.run {
                isSearching = false
                // Don't clear searchResults or cache - keep what we have
            }
        }
    }
}

struct BookSearchResultRow: View {
    let bookInfo: BookInfo

    private var yearPublished: String? {
        guard let publishedDate = bookInfo.publishedDate else { return nil }
        // Extract first 4 digits (year) from the published date
        let year = publishedDate.prefix(4)
        return year.count == 4 ? String(year) : nil
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Book cover with shadow
            BookCoverView(
                imageURL: bookInfo.coverImageURL,
                title: bookInfo.title,
                width: 64,
                height: 96
            )
            .shadow(color: Theme.Shadow.medium, radius: 8, y: 4)

            // Content
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Title
                Text(bookInfo.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Author
                Text(bookInfo.author)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)

                Spacer()

                // Metadata
                HStack(spacing: Theme.Spacing.xs) {
                    if let pages = bookInfo.totalPages {
                        HStack(spacing: 3) {
                            Image(systemName: "book.pages")
                                .font(.caption2)
                            Text("\(pages)")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    }

                    if let year = yearPublished {
                        if bookInfo.totalPages != nil {
                            Text("•")
                                .font(Theme.Typography.caption2)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }

                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(year)
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }

            Spacer(minLength: 0)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.md)
        .frame(minHeight: 112)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .shadow(color: Theme.Shadow.small, radius: Theme.Elevation.level2, y: 2)
    }
}

#Preview {
    BookSearchView { bookInfo in
        print("Selected: \(bookInfo.title)")
    }
}

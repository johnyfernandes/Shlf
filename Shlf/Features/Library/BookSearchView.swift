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
                    List {
                        ForEach(Array(searchResults.enumerated()), id: \.offset) { index, bookInfo in
                            Button {
                                onSelect(bookInfo)
                                dismiss()
                            } label: {
                                BookSearchResultRow(bookInfo: bookInfo)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
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

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            BookCoverView(
                imageURL: bookInfo.coverImageURL,
                title: bookInfo.title,
                width: 50,
                height: 75
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(bookInfo.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)

                Text(bookInfo.author)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xs) {
                    if let pages = bookInfo.totalPages {
                        Text("\(pages) pages")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }

                    if let published = bookInfo.publishedDate {
                        Text("•")
                            .foregroundStyle(Theme.Colors.tertiaryText)
                        Text(published)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

#Preview {
    BookSearchView { bookInfo in
        print("Selected: \(bookInfo.title)")
    }
}

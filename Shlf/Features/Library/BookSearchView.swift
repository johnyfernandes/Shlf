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
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private let bookAPI = BookAPIService()

    var body: some View {
        NavigationStack {
            Group {
                if searchResults.isEmpty && !isSearching && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No Results",
                        message: "Try a different search term"
                    )
                } else if searchResults.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: "Search for Books",
                        message: "Enter a title, author, or ISBN to search"
                    )
                } else {
                    List(Array(searchResults.enumerated()), id: \.offset) { index, bookInfo in
                        Button {
                            onSelect(bookInfo)
                            dismiss()
                        } label: {
                            BookSearchResultRow(bookInfo: bookInfo)
                        }
                    }
                }
            }
            .navigationTitle("Search Books")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Title, author, or ISBN")
            .onChange(of: searchText) { oldValue, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    await performSearch(query: newValue)
                }
            }
            .overlay {
                if isSearching {
                    ProgressView()
                        .scaleEffect(1.5)
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
                isSearching = false
            }
            return
        }

        await MainActor.run {
            isSearching = true
        }

        // Debounce - wait for user to stop typing
        try? await Task.sleep(for: .milliseconds(600))

        guard !Task.isCancelled else {
            await MainActor.run {
                isSearching = false
            }
            return
        }

        do {
            let results = try await bookAPI.searchBooks(query: query)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            print("Search error: \(error)")
            guard !Task.isCancelled else { return }

            await MainActor.run {
                searchResults = []
                isSearching = false
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

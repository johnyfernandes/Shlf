//
//  BookSearchView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct BookSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Binding var selectedTab: Int
    let onDismissAll: () -> Void

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
            ZStack(alignment: .top) {
                // Dynamic gradient background
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.08),
                        themeColor.color.opacity(0.02),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Group {
                    if searchResults.isEmpty && !isSearching && !searchText.isEmpty {
                        VStack {
                            Spacer()
                            ContentUnavailableView {
                                Label("No Results", systemImage: "magnifyingglass")
                            } description: {
                                Text("Try searching with a different title, author, or ISBN")
                            }
                            Spacer()
                        }
                    } else if searchResults.isEmpty && !isSearching {
                        VStack {
                            Spacer()
                            ContentUnavailableView {
                                Label("Search for Books", systemImage: "books.vertical")
                            } description: {
                                Text("Find books by title, author, or ISBN")
                            }
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(searchResults, id: \.olid) { bookInfo in
                                    NavigationLink {
                                        BookPreviewView(
                                            bookInfo: bookInfo,
                                            selectedTab: $selectedTab,
                                            onDismiss: onDismissAll
                                        )
                                    } label: {
                                        BookSearchResultRow(bookInfo: bookInfo)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 40)
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
                                .padding(24)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
    @Environment(\.themeColor) private var themeColor
    let bookInfo: BookInfo

    private var yearPublished: String? {
        guard let publishedDate = bookInfo.publishedDate else { return nil }
        // Extract 4-digit year from the published date using regex
        let pattern = #"(19|20)\d{2}"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: publishedDate, range: NSRange(publishedDate.startIndex..., in: publishedDate)),
           let range = Range(match.range, in: publishedDate) {
            return String(publishedDate[range])
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            // Book cover with shadow
            BookCoverView(
                imageURL: bookInfo.coverImageURL,
                title: bookInfo.title,
                width: 70,
                height: 105
            )
            .shadow(color: Theme.Shadow.medium, radius: 8, y: 4)

            // Content
            VStack(alignment: .leading, spacing: 6) {
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
                HStack(spacing: 6) {
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
        .padding(16)
        .frame(minHeight: 120)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    BookSearchView(
        selectedTab: .constant(1),
        onDismissAll: {
            print("Dismissed all")
        }
    )
}

//
//  LibraryView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]

    @State private var selectedFilter: ReadingStatus?
    @State private var searchText = ""
    @State private var showAddBook = false

    private var filteredBooks: [Book] {
        var books = allBooks

        if let filter = selectedFilter {
            books = books.filter { $0.readingStatus == filter }
        }

        if !searchText.isEmpty {
            books = books.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        return books
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredBooks.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: searchText.isEmpty ? "No Books" : "No Results",
                        message: searchText.isEmpty ? "Add your first book to get started" : "Try a different search term",
                        actionTitle: searchText.isEmpty ? "Add Book" : nil,
                        action: searchText.isEmpty ? { showAddBook = true } : nil
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            ForEach(filteredBooks) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    BookRow(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.Spacing.md)
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                filterPicker
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(.ultraThinMaterial)
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.xs) {
                FilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )

                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    FilterChip(
                        title: status.rawValue,
                        icon: status.icon,
                        count: allBooks.filter { $0.readingStatus == status }.count,
                        isSelected: selectedFilter == status,
                        action: { selectedFilter = status }
                    )
                }
            }
        }
    }
}

struct BookRow: View {
    let book: Book

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 70,
                height: 105
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(book.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)

                Text(book.author)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: book.bookType.icon)
                        .font(.caption)

                    Text(book.bookType.rawValue)
                        .font(Theme.Typography.caption)

                    if let totalPages = book.totalPages {
                        Text("•")
                        Text("\(totalPages) pages")
                            .font(Theme.Typography.caption)
                    }
                }
                .foregroundStyle(Theme.Colors.tertiaryText)

                if book.readingStatus == .currentlyReading, let totalPages = book.totalPages {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        ProgressView(value: book.progressPercentage, total: 100)
                            .tint(Theme.Colors.primary)

                        Text("\(book.currentPage) / \(totalPages) pages • \(Int(book.progressPercentage))%")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

struct FilterChip: View {
    let title: String
    var icon: String?
    var count: Int?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xxs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }

                Text(title)
                    .font(Theme.Typography.callout)

                if let count {
                    Text("(\(count))")
                        .font(Theme.Typography.caption)
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? Theme.Colors.primary : Theme.Colors.secondaryBackground)
            .foregroundStyle(isSelected ? .white : Theme.Colors.text)
            .clipShape(Capsule())
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self], inMemory: true)
}

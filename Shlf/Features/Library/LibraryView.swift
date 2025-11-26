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
            List {
                Section {
                    filterPicker
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if filteredBooks.isEmpty {
                    Section {
                        if searchText.isEmpty {
                            ContentUnavailableView {
                                Label("No Books", systemImage: "books.vertical")
                            } description: {
                                Text("Add your first book to get started")
                            } actions: {
                                Button("Add Book") {
                                    showAddBook = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(filteredBooks) { book in
                            NavigationLink(value: book) {
                                BookRow(book: book)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
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
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(
                    title: "All",
                    count: allBooks.count,
                    isSelected: selectedFilter == nil,
                    action: { selectedFilter = nil }
                )

                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    let count = allBooks.filter { $0.readingStatus == status }.count
                    FilterChip(
                        title: status.shortName,
                        icon: status.icon,
                        count: count,
                        isSelected: selectedFilter == status,
                        action: { selectedFilter = status }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
                width: 60,
                height: 90
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
        }
    }
}

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))

                if let count {
                    Text("(\(count))")
                        .font(.system(size: 13, weight: .regular))
                        .opacity(0.8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.Colors.primary : Theme.Colors.secondaryBackground)
            .foregroundStyle(isSelected ? .white : Theme.Colors.text)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self], inMemory: true)
}

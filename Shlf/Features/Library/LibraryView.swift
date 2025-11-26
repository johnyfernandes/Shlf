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
                        .listRowSeparator(.hidden)
                }

                if filteredBooks.isEmpty {
                    Section {
                        if searchText.isEmpty {
                            ContentUnavailableView {
                                Label("No Books", systemImage: "books.vertical.fill")
                            } description: {
                                Text("Add your first book to get started")
                            } actions: {
                                Button {
                                    showAddBook = true
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Book")
                                    }
                                    .primaryButton()
                                }
                            }
                        } else {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(filteredBooks) { book in
                            NavigationLink(value: book) {
                                BookRow(book: book)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search by title or author")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.primary)
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
                width: 65,
                height: 98
            )
            .shadow(color: Theme.Shadow.medium, radius: 6, y: 3)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(book.title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(2)

                    Text(book.author)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }

                HStack(spacing: Theme.Spacing.xs) {
                    StatusBadge(status: book.readingStatus)

                    if let totalPages = book.totalPages {
                        Text("•")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        HStack(spacing: 2) {
                            Image(systemName: "book.pages")
                                .font(.caption2)

                            Text("\(totalPages)")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }

                if book.readingStatus == .currentlyReading, let totalPages = book.totalPages {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        HStack {
                            Text("\(book.currentPage)")
                                .font(Theme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.primary)

                            Text("/ \(totalPages)")
                                .font(Theme.Typography.caption2)
                                .foregroundStyle(Theme.Colors.tertiaryText)

                            Spacer()

                            Text("\(Int(book.progressPercentage))%")
                                .font(Theme.Typography.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(Theme.Colors.primary)
                        }

                        ProgressView(value: book.progressPercentage, total: 100)
                            .tint(Theme.Colors.primary)
                            .scaleEffect(y: 0.8)
                    }
                    .padding(.top, Theme.Spacing.xxs)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
        .shadow(color: Theme.Shadow.small, radius: Theme.Elevation.level1, y: 1)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ReadingStatus

    private var badgeColor: Color {
        switch status {
        case .wantToRead: return Theme.Colors.secondary
        case .currentlyReading: return Theme.Colors.primary
        case .finished: return Theme.Colors.success
        case .didNotFinish: return Theme.Colors.tertiaryText
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)

            Text(status.shortName)
                .font(Theme.Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(badgeColor)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.vertical, Theme.Spacing.xxs)
        .background(badgeColor.opacity(0.12))
        .clipShape(Capsule())
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
                        .font(.system(size: 14, weight: .semibold))
                        .imageScale(.small)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))

                if let count {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ?
                                Color.white.opacity(0.25) :
                                Theme.Colors.tertiaryBackground
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.full, style: .continuous)
                            .fill(Theme.Colors.primary)
                            .shadow(color: Theme.Colors.primary.opacity(0.3), radius: 8, y: 4)
                    } else {
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.full, style: .continuous)
                            .fill(Theme.Colors.secondaryBackground)
                    }
                }
            )
            .foregroundStyle(isSelected ? .white : Theme.Colors.text)
            .animation(Theme.Animation.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self], inMemory: true)
}

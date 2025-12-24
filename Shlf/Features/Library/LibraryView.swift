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
    @Environment(\.themeColor) private var themeColor
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]
    @Binding var selectedTab: Int

    @State private var selectedFilter: ReadingStatus?
    @State private var searchText = ""
    @State private var showAddBook = false
    @State private var showLibraryShare = false

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

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Filter section
                        filterSection

                        // Books grid
                        if filteredBooks.isEmpty {
                            emptyState
                        } else {
                            booksSection
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
            }
            .navigationDestination(for: Book.self) { book in
                BookDetailView(book: book)
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search by title or author")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Menu {
                            Button {
                                showLibraryShare = true
                            } label: {
                                Label("Share Library", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundStyle(Theme.Colors.secondaryText)
                        }

                        Button {
                            showAddBook = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(themeColor.color)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView(selectedTab: $selectedTab)
            }
            .sheet(isPresented: $showLibraryShare) {
                LibraryShareSheetView()
            }
        }
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(
                    title: "All",
                    count: allBooks.count,
                    isSelected: selectedFilter == nil,
                    action: {
                        withAnimation(Theme.Animation.snappy) {
                            selectedFilter = nil
                        }
                    }
                )

                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    let count = allBooks.filter { $0.readingStatus == status }.count
                    FilterChip(
                        title: status.shortName,
                        icon: status.icon,
                        count: count,
                        isSelected: selectedFilter == status,
                        action: {
                            withAnimation(Theme.Animation.snappy) {
                                selectedFilter = status
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, -Theme.Spacing.lg)
        .padding(.leading, Theme.Spacing.lg)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()

            if searchText.isEmpty {
                EmptyStateView(
                    icon: "books.vertical.fill",
                    title: "No Books Yet",
                    message: "Add your first book to start building your library",
                    actionTitle: "Add Book",
                    action: { showAddBook = true }
                )
            } else {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: "No Results",
                    message: "Try searching with a different title or author"
                )
            }

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Books Section

    private var booksSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text(selectedFilter?.rawValue ?? "All Books")
                    .sectionHeader()

                Spacer()

                Text("\(filteredBooks.count)")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Colors.tertiaryBackground)
                    .clipShape(Capsule())
            }

            ForEach(filteredBooks) { book in
                NavigationLink(value: book) {
                    BookRow(book: book)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BookRow: View {
    @Environment(\.themeColor) private var themeColor
    let book: Book

    private var yearPublished: String? {
        guard let publishedDate = book.publishedDate else { return nil }
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
        HStack(spacing: Theme.Spacing.sm) {
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 60,
                height: 90
            )
            .shadow(color: Theme.Shadow.medium, radius: 6, y: 3)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(book.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(book.author)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)

                    if let totalPages = book.totalPages {
                        Text("•")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        HStack(spacing: 3) {
                            Image(systemName: "book.pages")
                                .font(.caption2)
                            Text("\(totalPages)")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    }

                    if let year = yearPublished {
                        Text("•")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.tertiaryText)

                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(year)
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }

                StatusBadge(status: book.readingStatus)

                if book.readingStatus == .currentlyReading, let totalPages = book.totalPages {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Text("\(book.currentPage)")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(themeColor.color)

                            Text("/ \(totalPages) pages")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)

                            Spacer()

                            Text("\(Int(book.progressPercentage))%")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(themeColor.color)
                        }

                        ProgressView(value: book.progressPercentage, total: 100)
                            .tint(themeColor.color)
                            .scaleEffect(y: 1.2)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.sm)
        .cardStyle(elevation: Theme.Elevation.level3)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    @Environment(\.themeColor) private var themeColor
    let status: ReadingStatus

    private var badgeColor: Color {
        switch status {
        case .wantToRead: return Theme.Colors.secondary
        case .currentlyReading: return themeColor.color
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
    @Environment(\.themeColor) private var themeColor
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
                            .fill(themeColor.color)
                            .shadow(color: themeColor.color.opacity(0.3), radius: 8, y: 4)
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
    LibraryView(selectedTab: .constant(1))
        .modelContainer(for: [Book.self], inMemory: true)
}

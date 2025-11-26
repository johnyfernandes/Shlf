//
//  AddBookView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]

    @State private var viewModel: AddBookViewModel

    init() {
        _viewModel = State(initialValue: AddBookViewModel())
    }

    private var canAddBook: Bool {
        if let profile = profiles.first, !profile.isProUser {
            return books.count < 5
        }
        return true
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showBookPreview {
                    bookPreviewView
                } else {
                    searchOptionsView
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if viewModel.showBookPreview {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            addBook()
                        }
                        .disabled(!viewModel.isValid)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showScanner) {
                BarcodeScannerView { isbn in
                    viewModel.isbn = isbn
                    Task {
                        await viewModel.fetchBookInfo()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSearch) {
                BookSearchView { bookInfo in
                    viewModel.populateFrom(bookInfo)
                    viewModel.showBookPreview = true
                }
            }
            .alert("Upgrade Required", isPresented: $viewModel.showUpgradeAlert) {
                Button("Upgrade to Pro") {
                    // Navigate to upgrade screen
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You've reached the limit of 5 books. Upgrade to Pro for unlimited books.")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }

    // MARK: - Search Options View

    private var searchOptionsView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Hero Section
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.Colors.primary.gradient)
                        .padding(.top, Theme.Spacing.xl)

                    Text("Add a Book")
                        .font(Theme.Typography.title2)
                        .foregroundStyle(Theme.Colors.text)

                    Text("Search or scan to get started")
                        .font(Theme.Typography.callout)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .padding(.bottom, Theme.Spacing.md)

                // Quick Actions
                VStack(spacing: Theme.Spacing.md) {
                    Button {
                        viewModel.showSearch = true
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.primary.opacity(0.12))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "magnifyingglass")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Search for a Book")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.text)

                                Text("Find by title, author, or ISBN")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                        .padding(Theme.Spacing.md)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await viewModel.scanBarcode()
                        }
                    } label: {
                        HStack(spacing: Theme.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.accent.opacity(0.12))
                                    .frame(width: 56, height: 56)

                                Image(systemName: "barcode.viewfinder")
                                    .font(.title2)
                                    .foregroundStyle(Theme.Colors.accent)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Scan Barcode")
                                    .font(Theme.Typography.headline)
                                    .foregroundStyle(Theme.Colors.text)

                                Text("Use your camera to scan ISBN")
                                    .font(Theme.Typography.subheadline)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                        .padding(Theme.Spacing.md)
                        .cardStyle()
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.md)

                // Manual Entry Option
                VStack(spacing: Theme.Spacing.md) {
                    HStack {
                        Rectangle()
                            .fill(Theme.Colors.tertiaryBackground)
                            .frame(height: 1)

                        Text("or")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                            .padding(.horizontal, Theme.Spacing.sm)

                        Rectangle()
                            .fill(Theme.Colors.tertiaryBackground)
                            .frame(height: 1)
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    Button {
                        viewModel.showBookPreview = true
                    } label: {
                        Text("Enter Details Manually")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.primary)
                            .padding(.vertical, Theme.Spacing.sm)
                    }
                }
                .padding(.top, Theme.Spacing.md)
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Book Preview View

    private var bookPreviewView: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Book Cover & Info
                VStack(spacing: Theme.Spacing.lg) {
                    BookCoverView(
                        imageURL: viewModel.coverImageURL,
                        title: viewModel.title,
                        width: 160,
                        height: 240
                    )
                    .shadow(color: Theme.Shadow.large, radius: 20, y: 10)

                    VStack(spacing: Theme.Spacing.xs) {
                        TextField("Title", text: $viewModel.title, axis: .vertical)
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)

                        TextField("Author", text: $viewModel.author)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.top, Theme.Spacing.xl)

                // Details Section
                VStack(spacing: Theme.Spacing.md) {
                    // ISBN & Pages
                    HStack(spacing: Theme.Spacing.md) {
                        if !viewModel.isbn.isEmpty {
                            VStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: "barcode")
                                    .font(.title3)
                                    .foregroundStyle(Theme.Colors.tertiaryText)

                                Text(viewModel.isbn)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)
                            .cardStyle()
                        }

                        if let totalPages = viewModel.totalPages {
                            VStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: "book.pages")
                                    .font(.title3)
                                    .foregroundStyle(Theme.Colors.tertiaryText)

                                Text("\(totalPages) pages")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)
                            .cardStyle()
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)

                    // Book Type
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Book Type")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .padding(.horizontal, Theme.Spacing.md)

                        Picker("Type", selection: $viewModel.bookType) {
                            ForEach(BookType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    // Reading Status
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Reading Status")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .padding(.horizontal, Theme.Spacing.md)

                        Menu {
                            Picker("Status", selection: $viewModel.readingStatus) {
                                ForEach(ReadingStatus.allCases, id: \.self) { status in
                                    Label(status.rawValue, systemImage: status.icon)
                                        .tag(status)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: viewModel.readingStatus.icon)
                                    .foregroundStyle(Theme.Colors.primary)

                                Text(viewModel.readingStatus.rawValue)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.text)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                            .padding(Theme.Spacing.md)
                            .cardStyle()
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }

                    // Current Progress (if reading)
                    if viewModel.readingStatus == .currentlyReading, let totalPages = viewModel.totalPages {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Current Progress")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .padding(.horizontal, Theme.Spacing.md)

                            HStack {
                                TextField("Current Page", value: $viewModel.currentPage, format: .number)
                                    .keyboardType(.numberPad)
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.text)

                                Text("/ \(totalPages)")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            .padding(Theme.Spacing.md)
                            .cardStyle()
                            .padding(.horizontal, Theme.Spacing.md)
                        }
                    }
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background)
    }

    private func addBook() {
        guard canAddBook else {
            viewModel.showUpgradeAlert = true
            return
        }

        let book = Book(
            title: viewModel.title,
            author: viewModel.author,
            isbn: viewModel.isbn.isEmpty ? nil : viewModel.isbn,
            coverImageURL: viewModel.coverImageURL,
            totalPages: viewModel.totalPages,
            currentPage: viewModel.currentPage,
            bookType: viewModel.bookType,
            readingStatus: viewModel.readingStatus,
            bookDescription: viewModel.bookDescription,
            subjects: viewModel.subjects,
            publisher: viewModel.publisher,
            publishedDate: viewModel.publishedDate,
            language: viewModel.language
        )

        modelContext.insert(book)
        dismiss()
    }
}

@Observable
final class AddBookViewModel {
    var title = ""
    var author = ""
    var isbn = ""
    var totalPages: Int?
    var currentPage = 0
    var bookType: BookType = .physical
    var readingStatus: ReadingStatus = .wantToRead
    var coverImageURL: URL?

    // Additional metadata
    var bookDescription: String?
    var subjects: [String]?
    var publisher: String?
    var publishedDate: String?
    var language: String?

    var showScanner = false
    var showSearch = false
    var showBookPreview = false
    var showUpgradeAlert = false
    var isLoading = false

    private let bookAPI = BookAPIService()
    private let scanner = BarcodeScannerService()

    var isValid: Bool {
        !title.isEmpty && !author.isEmpty
    }

    func scanBarcode() async {
        showScanner = true
    }

    func fetchBookInfo() async {
        guard !isbn.isEmpty else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let bookInfo = try await bookAPI.fetchBook(isbn: isbn)
            await MainActor.run {
                populateFrom(bookInfo)
            }
        } catch {
            print("Failed to fetch book info: \(error)")
        }
    }

    func populateFrom(_ bookInfo: BookInfo) {
        title = bookInfo.title
        author = bookInfo.author
        if let isbn = bookInfo.isbn {
            self.isbn = isbn
        }
        coverImageURL = bookInfo.coverImageURL
        totalPages = bookInfo.totalPages
        bookDescription = bookInfo.description
        subjects = bookInfo.subjects
        publishedDate = bookInfo.publishedDate
    }
}

#Preview {
    AddBookView()
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

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
            Form {
                Section {
                    Button {
                        viewModel.showSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Theme.Colors.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Search for a Book")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.text)

                                Text("Find by title, author, or ISBN")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }

                    Button {
                        Task {
                            await viewModel.scanBarcode()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundStyle(Theme.Colors.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Scan Barcode")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.text)

                                Text("Use your camera to scan ISBN")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }
                    }
                }

                Section("Or Add Manually") {
                    TextField("Title", text: $viewModel.title)
                    TextField("Author", text: $viewModel.author)
                    TextField("ISBN (Optional)", text: $viewModel.isbn)
                        .keyboardType(.numberPad)
                    TextField("Total Pages (Optional)", value: $viewModel.totalPages, format: .number)
                        .keyboardType(.numberPad)
                }

                Section("Book Type") {
                    Picker("Type", selection: $viewModel.bookType) {
                        ForEach(BookType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reading Status") {
                    Picker("Status", selection: $viewModel.readingStatus) {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Text(status.rawValue)
                                .tag(status)
                        }
                    }
                }

                if viewModel.readingStatus == .currentlyReading {
                    Section("Current Progress") {
                        TextField("Current Page", value: $viewModel.currentPage, format: .number)
                            .keyboardType(.numberPad)
                    }
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

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addBook()
                    }
                    .disabled(!viewModel.isValid)
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
        // Don't populate publisher, publishedDate, language from API
    }
}

#Preview {
    AddBookView()
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

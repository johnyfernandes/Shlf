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
    @Binding var selectedTab: Int

    @State private var viewModel: AddBookViewModel
    @State private var navigationPath = NavigationPath()

    init(selectedTab: Binding<Int>) {
        _selectedTab = selectedTab
        _viewModel = State(initialValue: AddBookViewModel())
    }

    private var canAddBook: Bool {
        if let profile = profiles.first, !profile.isProUser {
            return books.count < 5
        }
        return true
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            searchOptionsView
                .navigationTitle("Add Book")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: BookInfo.self) { bookInfo in
                    BookPreviewView(
                        bookInfo: bookInfo,
                        selectedTab: $selectedTab,
                        onDismiss: {
                            dismiss()
                        }
                    )
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            .sheet(isPresented: $viewModel.showScanner) {
                BarcodeScannerView { isbn in
                    viewModel.showScanner = false
                    Task {
                        if let bookInfo = await viewModel.fetchBookInfo(isbn: isbn) {
                            // Navigate to BookPreviewView - the Apple way!
                            navigationPath.append(bookInfo)
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSearch) {
                NavigationStack {
                    BookSearchView(
                        selectedTab: $selectedTab,
                        onDismissAll: {
                            dismiss()
                        }
                    )
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
            }
            .padding(.vertical, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background)
    }

    // MARK: - Book Preview View

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

    func fetchBookInfo(isbn: String) async -> BookInfo? {
        guard !isbn.isEmpty else { return nil }

        isLoading = true
        defer { isLoading = false }

        do {
            let bookInfo = try await bookAPI.fetchBook(isbn: isbn)
            return bookInfo
        } catch {
            print("Failed to fetch book info: \(error)")
            return nil
        }
    }

}

#Preview {
    AddBookView(selectedTab: .constant(1))
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

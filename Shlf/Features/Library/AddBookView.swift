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
    @Environment(\.themeColor) private var themeColor
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]
    @Binding var selectedTab: Int

    @State private var viewModel: AddBookViewModel
    @State private var navigationPath = NavigationPath()
    @State private var showManualEntry = false
    @State private var showUpgradeSheet = false

    init(selectedTab: Binding<Int>) {
        _selectedTab = selectedTab
        _viewModel = State(initialValue: AddBookViewModel())
    }

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profiles.first)
    }

    private var canAddBook: Bool {
        isProUser || books.count < 5
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            searchOptionsView
                .navigationTitle("Library.AddBook.Title")
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
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Common.Done") {
                            dismiss()
                        }
                        .foregroundStyle(themeColor.color)
                    }
                }
            .sheet(isPresented: $viewModel.showScanner) {
                BarcodeScanQueueView(
                    selectedTab: $selectedTab,
                    onDismissAll: {
                        dismiss()
                    }
                )
            }
            .sheet(isPresented: $viewModel.showSearch) {
                NavigationStack {
                    BookSearchView(
                        selectedTab: $selectedTab,
                        onDismissAll: {
                            dismiss()
                        },
                        showsDoneButton: true
                    )
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualBookEntryView(
                    selectedTab: $selectedTab,
                    onDismissAll: {
                        dismiss()
                    }
                )
            }
            .alert("Library.ManualEntry.Upgrade.Title", isPresented: $viewModel.showUpgradeAlert) {
                Button("Common.UpgradeToPro") {
                    showUpgradeSheet = true
                }
                Button("Common.Cancel", role: .cancel) {}
            } message: {
                Text("Library.ManualEntry.Upgrade.Message")
            }
            .sheet(isPresented: $showUpgradeSheet) {
                PaywallView()
            }
        }
    }

    // MARK: - Search Options View

    private var searchOptionsView: some View {
        ZStack(alignment: .top) {
            // Dynamic gradient background
            LinearGradient(
                colors: [
                    themeColor.color.opacity(0.12),
                    themeColor.color.opacity(0.04),
                    Theme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Hero Section
                    VStack(spacing: 16) {
                        Image(systemName: "books.vertical.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        themeColor.color,
                                        themeColor.color.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(.top, 24)

                        VStack(spacing: 8) {
                            Text("Library.AddBook.Hero.Title")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.Colors.text)

                            Text("Library.AddBook.Hero.Subtitle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Quick Actions
                    VStack(spacing: 16) {
                        Button {
                            if canAddBook {
                                viewModel.showSearch = true
                            } else {
                                viewModel.showUpgradeAlert = true
                            }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(themeColor.color.opacity(0.15))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "magnifyingglass")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(themeColor.color)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Library.AddBook.Search.Title")
                                        .font(.headline)
                                        .foregroundStyle(Theme.Colors.text)

                                    Text("Library.AddBook.Search.Subtitle")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(themeColor.color.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            if canAddBook {
                                Task {
                                    await viewModel.scanBarcode()
                                }
                            } else {
                                viewModel.showUpgradeAlert = true
                            }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.accent.opacity(0.15))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "barcode.viewfinder")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.Colors.accent)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Library.AddBook.Scan.Title")
                                        .font(.headline)
                                        .foregroundStyle(Theme.Colors.text)

                                    Text("Library.AddBook.Scan.Subtitle")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Theme.Colors.accent.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            if canAddBook {
                                showManualEntry = true
                            } else {
                                viewModel.showUpgradeAlert = true
                            }
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(Theme.Colors.secondary.opacity(0.15))
                                        .frame(width: 60, height: 60)

                                    Image(systemName: "square.and.pencil")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.Colors.secondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Library.AddBook.Manual.Title")
                                        .font(.headline)
                                        .foregroundStyle(Theme.Colors.text)

                                    Text("Library.AddBook.Manual.Subtitle")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Theme.Colors.tertiaryText)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Theme.Colors.secondary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .padding(.bottom, 40)
            }
        }
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
            #if DEBUG
            print("Failed to fetch book info: \(error)")
            #else
            AppLogger.logError(error, context: "Fetch book info", logger: AppLogger.network)
            #endif
            return nil
        }
    }

}

#Preview {
    AddBookView(selectedTab: .constant(1))
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

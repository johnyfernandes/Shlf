//
//  BookPreviewView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct BookPreviewView: View {
    let bookInfo: BookInfo
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]

    @State private var bookType: BookType = .physical
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var fullBookInfo: BookInfo?
    @State private var showUpgradeAlert = false

    private let bookAPI = BookAPIService()

    var displayInfo: BookInfo {
        fullBookInfo ?? bookInfo
    }

    private var canAddBook: Bool {
        if let profile = profiles.first, !profile.isProUser {
            return books.count < 5
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Book Cover & Info
                VStack(spacing: Theme.Spacing.lg) {
                    BookCoverView(
                        imageURL: displayInfo.coverImageURL,
                        title: displayInfo.title,
                        width: 160,
                        height: 240
                    )
                    .shadow(color: Theme.Shadow.large, radius: 20, y: 10)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text(displayInfo.title)
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.text)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)

                        Text(displayInfo.author)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                }
                .padding(.top, Theme.Spacing.xl)

                // Description
                if let description = displayInfo.description {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Description")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Text(description)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.text)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(Theme.Spacing.md)
                    .cardStyle()
                    .padding(.horizontal, Theme.Spacing.md)
                    .transition(.opacity)
                }

                // Details Section
                VStack(spacing: Theme.Spacing.md) {
                    // ISBN & Pages
                    if displayInfo.isbn != nil || displayInfo.totalPages != nil {
                        HStack(spacing: Theme.Spacing.md) {
                            if let isbn = displayInfo.isbn {
                                VStack(spacing: 4) {
                                    Image(systemName: "barcode")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Theme.Colors.tertiaryText)
                                        .frame(height: 18)

                                    Text(isbn)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .cardStyle()
                            }

                            if let totalPages = displayInfo.totalPages {
                                VStack(spacing: 4) {
                                    Image(systemName: "book.pages")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Theme.Colors.tertiaryText)
                                        .frame(height: 18)

                                    Text("\(totalPages) pages")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .cardStyle()
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .transition(.opacity)
                    }

                    // Subjects
                    if let subjects = displayInfo.subjects, !subjects.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Subjects")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)

                            FlowLayout(spacing: Theme.Spacing.xs) {
                                ForEach(subjects.prefix(10), id: \.self) { subject in
                                    Text(subject)
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.primary)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, Theme.Spacing.xxs)
                                        .background(Theme.Colors.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(Theme.Spacing.md)
                        .cardStyle()
                        .padding(.horizontal, Theme.Spacing.md)
                        .transition(.opacity)
                    }

                    // Settings Card
                    VStack(spacing: 0) {
                        // Book Type
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text("Book Type")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                                .textCase(.uppercase)

                            Picker("Type", selection: $bookType) {
                                ForEach(BookType.allCases, id: \.self) { type in
                                    Label(type.rawValue, systemImage: type.icon)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(Theme.Spacing.md)

                        Divider()
                            .padding(.leading, Theme.Spacing.md)

                        // Reading Status
                        Menu {
                            Picker("Status", selection: $readingStatus) {
                                ForEach(ReadingStatus.allCases, id: \.self) { status in
                                    Label(status.rawValue, systemImage: status.icon)
                                        .tag(status)
                                }
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.sm) {
                                Text("Reading Status")
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.text)

                                Spacer()

                                HStack(spacing: 6) {
                                    Image(systemName: readingStatus.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.Colors.secondaryText)

                                    Text(readingStatus.shortName)
                                        .font(Theme.Typography.subheadline)
                                        .foregroundStyle(Theme.Colors.secondaryText)

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Theme.Colors.tertiaryText)
                                }
                            }
                            .padding(Theme.Spacing.md)
                            .contentShape(Rectangle())
                        }
                    }
                    .background(Theme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg, style: .continuous))
                    .padding(.horizontal, Theme.Spacing.md)

                    // Current Progress (if reading)
                    if readingStatus == .currentlyReading, let totalPages = displayInfo.totalPages {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Current Progress")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(Theme.Colors.secondaryText)
                                .padding(.horizontal, Theme.Spacing.md)

                            HStack {
                                TextField("Current Page", value: $currentPage, format: .number)
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

                    // Add Button
                    Button {
                        addBookToLibrary()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Library")
                        }
                        .primaryButton(fullWidth: true)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.top, Theme.Spacing.md)
                }
            }
            .padding(.bottom, Theme.Spacing.xxl)
            .animation(.easeInOut(duration: 0.3), value: displayInfo.description)
            .animation(.easeInOut(duration: 0.3), value: displayInfo.subjects)
            .animation(.easeInOut(duration: 0.3), value: displayInfo.isbn)
            .animation(.easeInOut(duration: 0.3), value: displayInfo.totalPages)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Upgrade Required", isPresented: $showUpgradeAlert) {
            Button("Upgrade to Pro") {
                // Navigate to upgrade screen
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've reached the limit of 5 books. Upgrade to Pro for unlimited books.")
        }
        .task {
            // Fetch full details if we have OLID
            if let olid = bookInfo.olid {
                isLoading = true
                do {
                    fullBookInfo = try await bookAPI.fetchBookByOLID(olid: olid)
                } catch {
                    print("Failed to fetch full details: \(error)")
                }
                isLoading = false
            }
        }
    }

    private func addBookToLibrary() {
        guard canAddBook else {
            showUpgradeAlert = true
            return
        }

        let book = Book(
            title: displayInfo.title,
            author: displayInfo.author,
            isbn: displayInfo.isbn,
            coverImageURL: displayInfo.coverImageURL,
            totalPages: displayInfo.totalPages ?? 0,
            currentPage: readingStatus == .currentlyReading ? currentPage : 0,
            bookType: bookType,
            readingStatus: readingStatus,
            bookDescription: displayInfo.description,
            subjects: displayInfo.subjects,
            publisher: displayInfo.publisher,
            publishedDate: displayInfo.publishedDate,
            language: displayInfo.language
        )

        modelContext.insert(book)

        // Update profile stats if exists
        if let profile = profiles.first {
            let engine = GamificationEngine(modelContext: modelContext)
            engine.checkAchievements(for: profile)
        }

        // Dismiss the entire sheet
        onDismiss()
    }
}

#Preview {
    NavigationStack {
        BookPreviewView(
            bookInfo: BookInfo(
                title: "Tunnel People",
                author: "Teun Voeten",
                isbn: "9781101034965",
                coverImageURL: nil,
                totalPages: 304,
                publishedDate: "1998",
                description: "Following the homeless Manhattanites who, in the mid-1990s, chose to start a new life in the tunnel systems of the city.",
                subjects: ["Business", "Power", "Strategy"],
                publisher: "Penguin",
                language: "English",
                olid: "OL24274306M"
            ),
            onDismiss: {
                print("Dismissed")
            }
        )
    }
    .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}


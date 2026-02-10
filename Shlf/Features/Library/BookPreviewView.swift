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
    @Binding var selectedTab: Int
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.colorScheme) private var colorScheme
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]

    @State private var bookType: BookType = .physical
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var currentPage = 0
    @State private var excludeFromStats = true
    @State private var isLoading = false
    @State private var fullBookInfo: BookInfo?
    @State private var showUpgradeAlert = false
    @State private var showUpgradeSheet = false
    @State private var showDuplicateAlert = false
    @State private var existingBook: Book?

    private let bookAPI = BookAPIService()

    var displayInfo: BookInfo {
        fullBookInfo ?? bookInfo
    }

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profiles.first)
    }

    private var canAddBook: Bool {
        isProUser || books.count < 5
    }

    var body: some View {
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
                VStack(spacing: 20) {
                    // Hero Section - Cover & Title
                    VStack(spacing: 20) {
                        BookCoverView(
                            imageURL: displayInfo.coverImageURL,
                            title: displayInfo.title,
                            width: 140,
                            height: 210
                        )
                        .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
                        .padding(.top, 20)

                        VStack(spacing: 6) {
                            Text(displayInfo.title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)

                            Text(displayInfo.author)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)

                    // Content Sections
                    VStack(spacing: 16) {
                        // Description
                        if let description = displayInfo.description {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.alignleft")
                                        .font(.caption)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 16)

                                    Text("About")
                                        .font(.headline)
                                }

                                Text(description)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(6)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // Compact Info Pills
                        if displayInfo.isbn != nil || displayInfo.totalPages != nil {
                            HStack(spacing: 12) {
                                if let isbn = displayInfo.isbn {
                                    VStack(spacing: 6) {
                                        Image(systemName: "barcode")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text(isbn)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                                if let totalPages = displayInfo.totalPages {
                                    VStack(spacing: 6) {
                                        Image(systemName: "book.pages")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text(totalPages, format: .number)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                        }

                        // Subjects
                        if let subjects = displayInfo.subjects, !subjects.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption)
                                        .foregroundStyle(themeColor.color)
                                        .frame(width: 16)

                                    Text("Subjects")
                                        .font(.headline)
                                }

                                FlowLayout(spacing: 8) {
                                    ForEach(subjects.prefix(8), id: \.self) { subject in
                                        Text(subject)
                                            .font(.caption)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(themeColor.color.opacity(0.1), in: Capsule())
                                            .foregroundStyle(themeColor.color)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // Book Settings
                        VStack(spacing: 0) {
                            // Book Type
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Book Type")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                Picker("Type", selection: $bookType) {
                                    ForEach(BookType.allCases, id: \.self) { type in
                                        Label(type.displayNameKey, systemImage: type.icon)
                                            .tag(type)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .padding(16)

                            Divider()
                                .padding(.leading, 16)

                            // Reading Status
                            Menu {
                                Picker("Status", selection: $readingStatus) {
                                    ForEach(ReadingStatus.allCases, id: \.self) { status in
                                        Label(status.displayNameKey, systemImage: status.icon)
                                            .tag(status)
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text("Reading Status")
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Image(systemName: readingStatus.icon)
                                            .font(.subheadline)

                                        Text(readingStatus.shortNameKey)
                                            .font(.subheadline)

                                        Image(systemName: "chevron.right")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .foregroundStyle(.secondary)
                                }
                                .padding(16)
                                .contentShape(Rectangle())
                            }

                            // Current Progress (if reading)
                            if readingStatus == .currentlyReading, let totalPages = displayInfo.totalPages {
                                Divider()
                                    .padding(.leading, 16)

                                HStack {
                                    Text("Current Page")
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    HStack(spacing: 4) {
                                        TextField("0", value: $currentPage, format: .number)
                                            .keyboardType(.numberPad)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(themeColor.color)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 60)

                                        Text(
                                            String.localizedStringWithFormat(
                                                String(localized: "/ %lld"),
                                                totalPages
                                            )
                                        )
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(16)
                            }

                            if readingStatus == .finished {
                                Divider()
                                    .padding(.leading, 16)

                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Exclude from stats & XP", isOn: $excludeFromStats)
                                        .tint(themeColor.color)

                                    Text("Use this for books finished before you started tracking.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(16)
                            }
                        }
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // Add to Library Button
                        Button {
                            addBookToLibrary()
                        } label: {
                            HStack(spacing: 8) {
                                if isLoading {
                                    ProgressView()
                                        .tint(themeColor.onColor(for: colorScheme))
                                } else {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add to Library")
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(themeColor.onColor(for: colorScheme))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeColor.color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .disabled(isLoading)
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    addBookToLibrary()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(themeColor.color)
                    }
                }
                .disabled(isLoading)
            }
        }
        .alert("Upgrade Required", isPresented: $showUpgradeAlert) {
            Button("Upgrade to Pro") {
                showUpgradeSheet = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You've reached the limit of 5 books. Upgrade to Pro for unlimited books.")
        }
        .sheet(isPresented: $showUpgradeSheet) {
            PaywallView()
        }
        .alert("Book Already in Library", isPresented: $showDuplicateAlert) {
            Button("Cancel", role: .cancel) {}
        } message: {
            if let existing = existingBook {
                Text(
                    String.localizedStringWithFormat(
                        String(localized: "You already have \"%@\" by %@ in your library."),
                        existing.title,
                        existing.author
                    )
                )
            } else {
                Text("This book is already in your library.")
            }
        }
        .task {
            isLoading = true
            defer { isLoading = false }

            do {
                var bestOLID = bookInfo.olid

                if let workID = bookInfo.workID {
                    if let foundBestOLID = try await bookAPI.findBestEdition(workID: workID, originalTitle: bookInfo.title) {
                        bestOLID = foundBestOLID
                    }
                }

                if let olid = bestOLID {
                    let fetchedInfo = try await bookAPI.fetchBookByOLID(olid: olid)
                    fullBookInfo = mergedBookInfo(
                        fetched: fetchedInfo,
                        fallback: bookInfo,
                        preferredEditionID: olid
                    )
                }
            } catch {
                #if DEBUG
                print("Failed to fetch best edition: \(error)")
                #else
                AppLogger.logError(error, context: "Fetch best edition", logger: AppLogger.network)
                #endif
            }
        }
    }

    private func mergedBookInfo(
        fetched: BookInfo,
        fallback: BookInfo,
        preferredEditionID: String?
    ) -> BookInfo {
        let resolvedTitle = fetched.title.isEmpty ? fallback.title : fetched.title
        let resolvedAuthor = fetched.author == "Unknown Author" ? fallback.author : fetched.author
        let resolvedSubjects = fetched.subjects?.isEmpty == false ? fetched.subjects : fallback.subjects

        return BookInfo(
            title: resolvedTitle,
            author: resolvedAuthor,
            isbn: fetched.isbn ?? fallback.isbn,
            coverImageURL: fetched.coverImageURL ?? fallback.coverImageURL,
            totalPages: fetched.totalPages ?? fallback.totalPages,
            publishedDate: fetched.publishedDate ?? fallback.publishedDate,
            description: fetched.description ?? fallback.description,
            subjects: resolvedSubjects,
            publisher: fetched.publisher ?? fallback.publisher,
            language: fetched.language ?? fallback.language,
            olid: fetched.olid ?? preferredEditionID ?? fallback.olid,
            workID: fetched.workID ?? fallback.workID
        )
    }

    private func addBookToLibrary() {
        guard canAddBook else {
            showUpgradeAlert = true
            return
        }

        do {
            let duplicateCheck = try BookLibraryService.checkForDuplicate(
                title: displayInfo.title,
                author: displayInfo.author,
                isbn: displayInfo.isbn,
                in: modelContext
            )

            switch duplicateCheck {
            case .duplicate(let existing):
                existingBook = existing
                showDuplicateAlert = true
                return

            case .noDuplicate:
                let totalPagesValue = displayInfo.totalPages ?? 0
                let initialCurrentPage: Int
                switch readingStatus {
                case .currentlyReading:
                    initialCurrentPage = currentPage
                case .finished:
                    initialCurrentPage = totalPagesValue
                default:
                    initialCurrentPage = 0
                }

                let clampedCurrentPage: Int
                if totalPagesValue > 0 {
                    clampedCurrentPage = min(initialCurrentPage, totalPagesValue)
                } else {
                    clampedCurrentPage = max(0, initialCurrentPage)
                }

                let resolvedSubjects = displayInfo.subjects ?? []
                let canonicalSubjects: [String]?
                if let profile = profiles.first {
                    let canonical = profile.registerSubjects(resolvedSubjects)
                    canonicalSubjects = canonical.isEmpty ? nil : canonical
                } else {
                    canonicalSubjects = resolvedSubjects.isEmpty ? nil : resolvedSubjects
                }

                let book = Book(
                    title: displayInfo.title,
                    author: displayInfo.author,
                    isbn: displayInfo.isbn,
                    coverImageURL: displayInfo.coverImageURL ?? bookInfo.coverImageURL,
                    totalPages: totalPagesValue,
                    currentPage: clampedCurrentPage,
                    bookType: bookType,
                    readingStatus: readingStatus,
                    bookDescription: displayInfo.description,
                    subjects: canonicalSubjects,
                    publisher: displayInfo.publisher,
                    publishedDate: displayInfo.publishedDate,
                    language: displayInfo.language,
                    openLibraryWorkID: displayInfo.workID,
                    openLibraryEditionID: displayInfo.olid
                )

                let finishedDate = Date()
                if readingStatus == .finished {
                    book.dateFinished = finishedDate
                }

                modelContext.insert(book)

                if readingStatus == .finished && excludeFromStats {
                    let endPage = book.currentPage
                    let session = ReadingSession(
                        startDate: finishedDate,
                        endDate: finishedDate,
                        startPage: 0,
                        endPage: endPage,
                        durationMinutes: 0,
                        xpEarned: 0,
                        isAutoGenerated: false,
                        countsTowardStats: false,
                        isImported: true,
                        book: book
                    )
                    modelContext.insert(session)
                }

                if let profile = profiles.first {
                    let engine = GamificationEngine(modelContext: modelContext)
                    engine.checkAchievements(for: profile)
                }

                WidgetDataExporter.exportSnapshot(modelContext: modelContext)

                if readingStatus == .currentlyReading {
                    Task {
                        await WatchConnectivityManager.shared.syncBooksToWatch()
                    }
                }

                selectedTab = 1
                onDismiss()
            }
        } catch {
            #if DEBUG
            print("Error checking for duplicates: \(error)")
            #else
            AppLogger.logError(error, context: "Check duplicates", logger: AppLogger.network)
            #endif
            showDuplicateAlert = true
        }
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
                olid: "OL24274306M",
                workID: "OL21459846W"
            ),
            selectedTab: .constant(1),
            onDismiss: {
                #if DEBUG
                print("Dismissed")
                #endif
            }
        )
    }
    .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

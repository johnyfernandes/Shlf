//
//  ManualBookEntryView.swift
//  Shlf
//
//  Manual book entry for creating books from scratch
//

import SwiftUI
import SwiftData
import PhotosUI

struct ManualBookEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]
    @Binding var selectedTab: Int
    let onDismissAll: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showDiscardAlert = false
    @State private var showUpgradeAlert = false
    @State private var showUpgradeSheet = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverImage: UIImage?

    // Book properties
    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var totalPages = ""
    @State private var currentPage = 0
    @State private var bookType: BookType = .physical
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var excludeFromStats = true
    @State private var rating: Int? = nil
    @State private var publisher = ""
    @State private var publishedDate = ""
    @State private var language = ""
    @State private var bookDescription = ""
    @State private var notes = ""
    @State private var selectedSubjects: [String] = []
    @State private var showSubjectPicker = false

    enum Field: Hashable {
        case title, author, isbn, totalPages, currentPage
        case publisher, publishedDate, language, description, notes
    }

    private var hasContent: Bool {
        !title.isEmpty || !author.isEmpty || !isbn.isEmpty ||
        !totalPages.isEmpty || currentPage > 0
    }

    private var isValid: Bool {
        !title.isEmpty && !author.isEmpty
    }

    private var isProUser: Bool {
        ProAccess.isProUser(profile: profiles.first)
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var canAddBook: Bool {
        isProUser || books.count < 5
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background gradient
                LinearGradient(
                    colors: [
                        themeColor.color.opacity(0.08),
                        Theme.Colors.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 400)
                .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(spacing: 0) {
                        // Hero Section
                        heroSection

                        // Content Sections
                        VStack(spacing: 24) {
                            essentialInfoSection
                            progressSection
                            typeStatusSection
                            publishingDetailsSection
                            descriptionSection
                            subjectsSection
                            notesSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if hasContent {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Text("Cancel")
                            .fontWeight(.medium)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveBook()
                    } label: {
                        Text("Add Book")
                            .fontWeight(.semibold)
                    }
                    .tint(themeColor.color)
                    .disabled(!isValid)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button {
                            focusedField = nil
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .font(.body.weight(.medium))
                                .foregroundStyle(themeColor.color)
                        }
                    }
                }
            }
            .alert("Discard Entry?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Are you sure you want to discard this book entry?")
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
            .sheet(isPresented: $showSubjectPicker) {
                if let profile {
                    SubjectPickerView(profile: profile, selectedSubjects: $selectedSubjects)
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 20) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        LinearGradient(
                            colors: [
                                themeColor.color.opacity(0.3),
                                themeColor.color.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VStack(spacing: 8) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(themeColor.color.opacity(0.6))

                            Text("Add Cover")
                                .font(.caption2)
                                .foregroundStyle(themeColor.color.opacity(0.6))
                        }
                    }
                }
                .frame(width: 140, height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                        .offset(x: 6, y: 6)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 24)
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let newValue,
                       let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        coverImage = uiImage
                    }
                }
            }

            ratingCompactSection
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Essential Info Section

    private var essentialInfoSection: some View {
        VStack(spacing: 16) {
            ModernTextField(
                title: "Title",
                text: $title,
                icon: "text.alignleft",
                placeholder: "Enter book title",
                focused: $focusedField,
                field: .title
            )

            ModernTextField(
                title: "Author",
                text: $author,
                icon: "person.fill",
                placeholder: "Enter author name",
                focused: $focusedField,
                field: .author
            )

            ModernTextField(
                title: "ISBN",
                text: $isbn,
                icon: "barcode",
                placeholder: "Optional",
                focused: $focusedField,
                field: .isbn
            )
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(localized("Reading Progress", locale: locale))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 2)

            Text(localized("Update your current page and total pages.", locale: locale))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            HStack(spacing: 10) {
                CompactNumberField(
                    title: localized("Current Page", locale: locale),
                    value: $currentPage,
                    icon: "bookmark.fill",
                    focused: $focusedField,
                    field: .currentPage
                )

                CompactNumberField(
                    title: localized("Total Pages", locale: locale),
                    value: Binding(
                        get: { Int(totalPages) ?? 0 },
                        set: { totalPages = $0 == 0 ? "" : "\($0)" }
                    ),
                    icon: "book.pages",
                    focused: $focusedField,
                    field: .totalPages
                )
            }

            if let total = Int(totalPages), total > 0 {
                let progress = Double(currentPage) / Double(total) * 100
                VStack(spacing: 8) {
                    HStack {
                        Text(
                            String.localizedStringWithFormat(
                                localized("%lld%% Complete", locale: locale),
                                Int(progress)
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text(
                            String.localizedStringWithFormat(
                                localized("%lld pages left", locale: locale),
                                max(0, total - currentPage)
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }

                    ProgressView(value: progress, total: 100)
                        .tint(themeColor.color)
                }
                .padding(12)
                .background(themeColor.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Type & Status Section

    private var typeStatusSection: some View {
        VStack(spacing: 16) {
            OutlineMenuField(
                title: "Book Type",
                icon: "books.vertical.fill",
                selection: $bookType,
                label: {
                    HStack(spacing: 6) {
                        Image(systemName: bookType.icon)
                            .frame(width: 14)
                        Text(bookType.displayNameKey)
                    }
                }
            ) {
                ForEach(BookType.allCases, id: \.self) { type in
                    Label(type.displayNameKey, systemImage: type.icon)
                        .tag(type)
                }
            }

            OutlineMenuField(
                title: "Reading Status",
                icon: "book.fill",
                selection: $readingStatus,
                label: {
                    HStack(spacing: 6) {
                        Image(systemName: readingStatus.icon)
                            .frame(width: 14)
                        Text(readingStatus.displayNameKey)
                    }
                }
            ) {
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Label(status.displayNameKey, systemImage: status.icon)
                        .tag(status)
                }
            }

            if readingStatus == .finished {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Exclude from stats & XP", isOn: $excludeFromStats)
                        .tint(themeColor.color)

                    Text("Use this for books finished before you started tracking.")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
                .padding(16)
                .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Rating Section

    private var ratingCompactSection: some View {
        VStack(spacing: 8) {
            Text("Rating")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.secondaryText)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { starRating in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            if rating == starRating {
                                rating = nil
                            } else {
                                rating = starRating
                            }
                        }
                    } label: {
                        Image(systemName: (rating ?? 0) >= starRating ? "star.fill" : "star")
                            .font(.subheadline)
                            .foregroundStyle((rating ?? 0) >= starRating ? themeColor.color : Theme.Colors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Theme.Colors.secondaryBackground, in: Capsule())
        }
    }

    // MARK: - Publishing Details Section

    private var publishingDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 20)

                Text(localized("Publishing Details", locale: locale))
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            VStack(spacing: 12) {
                ModernTextField(
                    title: localized("Publisher", locale: locale),
                    text: $publisher,
                    icon: "building.2.fill",
                    placeholder: localized("Optional", locale: locale),
                    focused: $focusedField,
                    field: .publisher
                )

                ModernTextField(
                    title: localized("Published Date", locale: locale),
                    text: $publishedDate,
                    icon: "calendar",
                    placeholder: localized("e.g., 2024", locale: locale),
                    focused: $focusedField,
                    field: .publishedDate
                )

                ModernTextField(
                    title: localized("Language", locale: locale),
                    text: $language,
                    icon: "globe",
                    placeholder: "e.g., English",
                    focused: $focusedField,
                    field: .language
                )
            }
        }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.alignleft")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 20)

                Text("Description")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            ZStack(alignment: .topLeading) {
                if bookDescription.isEmpty && focusedField != .description {
                    Text("Add a brief description of the book...")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $bookDescription)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
                    .focused($focusedField, equals: .description)
            }
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Subjects Section

    private var subjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tag.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 20)

                Text("Subjects")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            if selectedSubjects.isEmpty {
                Text("Add genres or topics to organize this book.")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.secondaryText)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(selectedSubjects, id: \.self) { subject in
                        Text(subject)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(themeColor.color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(themeColor.color.opacity(0.12), in: Capsule())
                    }
                }
            }

            Button {
                showSubjectPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                    Text(selectedSubjects.isEmpty ? "Add subjects" : "Edit subjects")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(themeColor.color)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(themeColor.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 20)

                Text("Personal Notes")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            ZStack(alignment: .topLeading) {
                if notes.isEmpty && focusedField != .notes {
                    Text("Add your personal thoughts and notes...")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $notes)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
                    .focused($focusedField, equals: .notes)
            }
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Actions

    private func saveBook() {
        guard canAddBook else {
            showUpgradeAlert = true
            return
        }

        let totalPagesValue = Int(totalPages)
        let maxPages = totalPagesValue ?? currentPage
        let clampedCurrentPage = min(maxPages, currentPage)
        let finalCurrentPage = readingStatus == .finished ? maxPages : clampedCurrentPage

        let book = Book(
            title: title,
            author: author,
            totalPages: totalPagesValue,
            currentPage: max(0, finalCurrentPage)
        )

        book.isbn = isbn.isEmpty ? nil : isbn
        book.bookType = bookType
        book.readingStatus = readingStatus
        book.rating = rating
        book.publisher = publisher.isEmpty ? nil : publisher
        book.publishedDate = publishedDate.isEmpty ? nil : publishedDate
        book.language = language.isEmpty ? nil : language
        book.bookDescription = bookDescription.isEmpty ? nil : bookDescription
        book.notes = notes

        if let profile {
            let canonical = profile.registerSubjects(selectedSubjects)
            book.subjects = canonical.isEmpty ? nil : canonical
        } else if !selectedSubjects.isEmpty {
            book.subjects = selectedSubjects
        }

        let finishedDate = Date()
        if readingStatus == .finished {
            book.dateFinished = finishedDate
        }

        // Save cover image to documents directory if available
        if let coverImage {
            if let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                let fileManager = FileManager.default
                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = documentsURL.appendingPathComponent(fileName)
                    try? imageData.write(to: fileURL)
                    book.coverImageURL = fileURL
                }
            }
        }

        modelContext.insert(book)

        if readingStatus == .finished && excludeFromStats {
            let session = ReadingSession(
                startDate: finishedDate,
                endDate: finishedDate,
                startPage: 0,
                endPage: book.currentPage,
                durationMinutes: 0,
                xpEarned: 0,
                isAutoGenerated: false,
                countsTowardStats: false,
                isImported: true,
                book: book
            )
            modelContext.insert(session)
        }
        try? modelContext.save()

        // Sync to Watch if book is "Currently Reading"
        if readingStatus == .currentlyReading {
            Task { @MainActor in
                await WatchConnectivityManager.shared.syncBooksToWatch()
            }
        }

        onDismissAll()
    }
}

#Preview {
    ManualBookEntryView(selectedTab: .constant(1), onDismissAll: {})
        .modelContainer(for: [Book.self], inMemory: true)
}

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
    @Binding var selectedTab: Int
    let onDismissAll: () -> Void

    @FocusState private var focusedField: Field?
    @State private var showDiscardAlert = false
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
    @State private var rating: Int? = nil
    @State private var publisher = ""
    @State private var publishedDate = ""
    @State private var language = ""
    @State private var bookDescription = ""
    @State private var notes = ""

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
                            ratingSection
                            publishingDetailsSection
                            descriptionSection
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 20)

                Text("Reading Progress")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                            .font(.caption2)
                            .foregroundStyle(themeColor.color)
                            .frame(width: 14)

                        Text("Total Pages")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .padding(.leading, 4)

                    TextField("0", text: $totalPages)
                        .font(Theme.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(focusedField == .totalPages ? themeColor.color : .clear, lineWidth: 2)
                        )
                        .focused($focusedField, equals: .totalPages)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundStyle(themeColor.color)
                            .frame(width: 14)

                        Text("Current Page")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .padding(.leading, 4)

                    TextField("0", value: $currentPage, format: .number)
                        .font(Theme.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.Colors.text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(focusedField == .currentPage ? themeColor.color : .clear, lineWidth: 2)
                        )
                        .focused($focusedField, equals: .currentPage)
                }
            }

            if let total = Int(totalPages), total > 0 {
                let progress = Double(currentPage) / Double(total) * 100
                VStack(spacing: 8) {
                    HStack {
                        Text("\(Int(progress))% Complete")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text("\(max(0, total - currentPage)) pages left")
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
            ModernPicker(
                title: "Book Type",
                icon: "books.vertical.fill",
                selection: $bookType
            ) {
                ForEach(BookType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon)
                        .tag(type)
                }
            }

            ModernPicker(
                title: "Reading Status",
                icon: "book.fill",
                selection: $readingStatus
            ) {
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Label(status.rawValue, systemImage: status.icon)
                        .tag(status)
                }
            }
        }
    }

    // MARK: - Rating Section

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(themeColor.color)
                    .frame(width: 20)

                Text("Rating")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { starRating in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if rating == starRating {
                                rating = nil
                            } else {
                                rating = starRating
                            }
                        }
                    } label: {
                        Image(systemName: (rating ?? 0) >= starRating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle((rating ?? 0) >= starRating ? themeColor.color : Theme.Colors.tertiaryText)
                            .symbolEffect(.bounce, value: rating)
                    }
                    .buttonStyle(.plain)
                }

                if rating != nil {
                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            rating = nil
                        }
                    } label: {
                        Text("Clear")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }
            .padding(16)
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

                Text("Publishing Details")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            VStack(spacing: 12) {
                ModernTextField(
                    title: "Publisher",
                    text: $publisher,
                    icon: "building.2.fill",
                    placeholder: "Optional",
                    focused: $focusedField,
                    field: .publisher
                )

                ModernTextField(
                    title: "Published Date",
                    text: $publishedDate,
                    icon: "calendar",
                    placeholder: "e.g., 2024",
                    focused: $focusedField,
                    field: .publishedDate
                )

                ModernTextField(
                    title: "Language",
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
        let book = Book(
            title: title,
            author: author,
            totalPages: Int(totalPages),
            currentPage: currentPage
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
        try? modelContext.save()

        onDismissAll()
    }
}

#Preview {
    ManualBookEntryView(selectedTab: .constant(1), onDismissAll: {})
        .modelContainer(for: [Book.self], inMemory: true)
}

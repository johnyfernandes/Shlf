//
//  EditBookView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Bindable var book: Book
    @Query private var profiles: [UserProfile]

    @FocusState private var focusedField: Field?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverImage: UIImage?
    @State private var hasUnsavedChanges = false
    @State private var showDiscardAlert = false
    @State private var showSubjectPicker = false
    @State private var selectedSubjects: [String] = []

    enum Field: Hashable {
        case title, author, isbn, totalPages, currentPage
        case publisher, publishedDate, language, description, notes
    }

    private var profile: UserProfile? {
        profiles.first
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background gradient that extends under the toolbar
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
                        // Hero Section - Cover & Title
                        heroSectionContent

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if hasUnsavedChanges {
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
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .tint(themeColor.color)
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
            .alert("Discard Changes?", isPresented: $showDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .sheet(isPresented: $showSubjectPicker) {
                if let profile {
                    SubjectPickerView(profile: profile, selectedSubjects: $selectedSubjects)
                }
            }
            .task {
                if selectedSubjects.isEmpty {
                    selectedSubjects = book.subjects ?? []
                }
            }
        }
    }

    // MARK: - Hero Section

    private var heroSectionContent: some View {
        VStack(spacing: 16) {
            // Cover Image
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                ZStack {
                    if let coverImage {
                        Image(uiImage: coverImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if let coverURL = book.coverImageURL {
                        CachedAsyncImage(url: coverURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            coverPlaceholder
                        }
                    } else {
                        coverPlaceholder
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
                        hasUnsavedChanges = true
                    }
                }
            }

            ratingCompactSection
        }
        .frame(maxWidth: .infinity)
    }

    private var coverPlaceholder: some View {
        ZStack {
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

    // MARK: - Essential Info Section

    private var essentialInfoSection: some View {
        VStack(spacing: 16) {
            ModernTextField(
                title: "Title",
                text: $book.title,
                icon: "text.alignleft",
                placeholder: "Enter book title",
                focused: $focusedField,
                field: .title
            )
            .onChange(of: book.title) { _, _ in hasUnsavedChanges = true }

            ModernTextField(
                title: "Author",
                text: $book.author,
                icon: "person.fill",
                placeholder: "Enter author name",
                focused: $focusedField,
                field: .author
            )
            .onChange(of: book.author) { _, _ in hasUnsavedChanges = true }

            ModernTextField(
                title: "ISBN",
                text: Binding(
                    get: { book.isbn ?? "" },
                    set: { book.isbn = $0.isEmpty ? nil : $0 }
                ),
                icon: "barcode",
                placeholder: "Optional",
                focused: $focusedField,
                field: .isbn
            )
            .onChange(of: book.isbn) { _, _ in hasUnsavedChanges = true }
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

                Text("Reading Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 2)

            Text("Update your current page and total pages.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            HStack(spacing: 10) {
                CompactNumberField(
                    title: "Current Page",
                    value: $book.currentPage,
                    icon: "bookmark.fill",
                    focused: $focusedField,
                    field: .currentPage
                )

                CompactNumberField(
                    title: "Total Pages",
                    value: Binding(
                        get: { book.totalPages ?? 0 },
                        set: { book.totalPages = $0 == 0 ? nil : $0 }
                    ),
                    icon: "book.pages",
                    focused: $focusedField,
                    field: .totalPages
                )
            }

            if let total = book.totalPages, total > 0 {
                VStack(spacing: 8) {
                    HStack {
                        Text("\(Int(book.progressPercentage))% Complete")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text("\(max(0, total - book.currentPage)) pages left")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }

                    ProgressView(value: book.progressPercentage, total: 100)
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
                selection: $book.bookType,
                label: {
                    HStack(spacing: 6) {
                        Image(systemName: book.bookType.icon)
                            .frame(width: 14)
                        Text(book.bookType.displayNameKey)
                    }
                }
            ) {
                ForEach(BookType.allCases, id: \.self) { type in
                    Label(type.displayNameKey, systemImage: type.icon)
                        .tag(type)
                }
            }
            .onChange(of: book.bookType) { _, _ in hasUnsavedChanges = true }

            OutlineMenuField(
                title: "Reading Status",
                icon: "book.fill",
                selection: $book.readingStatus,
                label: {
                    HStack(spacing: 6) {
                        Image(systemName: book.readingStatus.icon)
                            .frame(width: 14)
                        Text(book.readingStatus.displayNameKey)
                    }
                }
            ) {
                ForEach(ReadingStatus.allCases, id: \.self) { status in
                    Label(status.displayNameKey, systemImage: status.icon)
                        .tag(status)
                }
            }
            .onChange(of: book.readingStatus) { _, _ in hasUnsavedChanges = true }
        }
    }

    // MARK: - Rating Compact

    private var ratingCompactSection: some View {
        VStack(spacing: 8) {
            Text("Rating")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.Colors.secondaryText)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { rating in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            if book.rating == rating {
                                book.rating = nil
                            } else {
                                book.rating = rating
                            }
                            hasUnsavedChanges = true
                        }
                    } label: {
                        Image(systemName: (book.rating ?? 0) >= rating ? "star.fill" : "star")
                            .font(.subheadline)
                            .foregroundStyle((book.rating ?? 0) >= rating ? themeColor.color : Theme.Colors.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
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

                Text("Publishing Details")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
            }
            .padding(.leading, 4)

            VStack(spacing: 12) {
                ModernTextField(
                    title: "Publisher",
                    text: Binding(
                        get: { book.publisher ?? "" },
                        set: { book.publisher = $0.isEmpty ? nil : $0 }
                    ),
                    icon: "building.2.fill",
                    placeholder: "Optional",
                    focused: $focusedField,
                    field: .publisher
                )

                ModernTextField(
                    title: "Published Date",
                    text: Binding(
                        get: { book.publishedDate ?? "" },
                        set: { book.publishedDate = $0.isEmpty ? nil : $0 }
                    ),
                    icon: "calendar",
                    placeholder: "e.g., 2024",
                    focused: $focusedField,
                    field: .publishedDate
                )

                ModernTextField(
                    title: "Language",
                    text: Binding(
                        get: { book.language ?? "" },
                        set: { book.language = $0.isEmpty ? nil : $0 }
                    ),
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
                if (book.bookDescription ?? "").isEmpty && focusedField != .description {
                    Text("Add a brief description of the book...")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                TextEditor(text: Binding(
                    get: { book.bookDescription ?? "" },
                    set: { book.bookDescription = $0.isEmpty ? nil : $0 }
                ))
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.text)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minHeight: 120)
                .focused($focusedField, equals: .description)
                .onChange(of: book.bookDescription) { _, _ in hasUnsavedChanges = true }
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
                if book.notes.isEmpty && focusedField != .notes {
                    Text("Add your personal thoughts and notes...")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $book.notes)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
                    .focused($focusedField, equals: .notes)
                    .onChange(of: book.notes) { _, _ in hasUnsavedChanges = true }
            }
            .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        // Save cover image if a new one was selected
        if let coverImage {
            if let imageData = coverImage.jpegData(compressionQuality: 0.8) {
                let fileManager = FileManager.default
                if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
                    // Delete old cover if it exists and is a local file
                    if let oldURL = book.coverImageURL,
                       oldURL.isFileURL {
                        try? fileManager.removeItem(at: oldURL)
                    }

                    let fileName = "\(UUID().uuidString).jpg"
                    let fileURL = documentsURL.appendingPathComponent(fileName)
                    try? imageData.write(to: fileURL)
                    book.coverImageURL = fileURL
                }
            }
        }

        if let profile {
            let canonical = profile.registerSubjects(selectedSubjects)
            book.subjects = canonical.isEmpty ? nil : canonical
        } else {
            book.subjects = selectedSubjects.isEmpty ? nil : selectedSubjects
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Modern Text Field

struct ModernTextField<Field: Hashable>: View {
    let title: LocalizedStringKey
    @Binding var text: String
    let icon: String
    let placeholder: LocalizedStringKey
    @FocusState.Binding var focused: Field?
    let field: Field
    @Environment(\.themeColor) private var themeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(.leading, 4)

            TextField(placeholder, text: $text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(focused == field ? themeColor.color : .clear, lineWidth: 2)
                )
                .focused($focused, equals: field)
        }
    }
}

// MARK: - Compact Number Field

struct CompactNumberField<Field: Hashable>: View {
    let title: String
    @Binding var value: Int
    let icon: String
    @FocusState.Binding var focused: Field?
    let field: Field
    @Environment(\.themeColor) private var themeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 14)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(.leading, 2)

            TextField("0", value: $value, format: .number)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.Colors.text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(focused == field ? themeColor.color : .clear, lineWidth: 2)
                )
                .focused($focused, equals: field)
        }
    }
}

// MARK: - Outline Menu Field

struct OutlineMenuField<Selection: Hashable, LabelContent: View, Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @Binding var selection: Selection
    @ViewBuilder let label: () -> LabelContent
    @ViewBuilder let content: () -> Content
    @Environment(\.themeColor) private var themeColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(themeColor.color)
                    .frame(width: 16)

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(.leading, 2)

            Menu {
                Picker("", selection: $selection) {
                    content()
                }
            } label: {
                HStack(spacing: 8) {
                    label()
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption2)
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(themeColor.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    Capsule()
                        .strokeBorder(themeColor.color.opacity(0.6), lineWidth: 1)
                )
                .contentShape(Capsule())
            }
        }
    }
}

#Preview {
    EditBookView(book: Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        totalPages: 218,
        currentPage: 45
    ))
    .modelContainer(for: [Book.self], inMemory: true)
}

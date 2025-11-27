//
//  BookPreviewView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct BookPreviewView: View {
    let bookInfo: BookInfo
    let onAdd: (BookInfo) -> Void

    @State private var bookType: BookType = .physical
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var fullBookInfo: BookInfo?

    private let bookAPI = BookAPIService()

    var displayInfo: BookInfo {
        fullBookInfo ?? bookInfo
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
                    HStack(spacing: Theme.Spacing.md) {
                        if let isbn = displayInfo.isbn {
                            VStack(spacing: Theme.Spacing.xxs) {
                                Image(systemName: "barcode")
                                    .font(.title3)
                                    .foregroundStyle(Theme.Colors.tertiaryText)

                                Text(isbn)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.md)
                            .cardStyle()
                        }

                        if let totalPages = displayInfo.totalPages {
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

                    // Book Type
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Book Type")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .padding(.horizontal, Theme.Spacing.md)

                        Picker("Type", selection: $bookType) {
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
                            Picker("Status", selection: $readingStatus) {
                                ForEach(ReadingStatus.allCases, id: \.self) { status in
                                    Label(status.rawValue, systemImage: status.icon)
                                        .tag(status)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: readingStatus.icon)
                                    .foregroundStyle(Theme.Colors.primary)

                                Text(readingStatus.rawValue)
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
                        onAdd(displayInfo)
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
        }
        .background(Theme.Colors.background)
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
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
            onAdd: { _ in
                print("Added")
            }
        )
    }
}


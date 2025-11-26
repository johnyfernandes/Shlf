//
//  HomeView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.dateAdded, order: .reverse)
    private var allBooks: [Book]

    private var currentlyReading: [Book] {
        allBooks.filter { $0.readingStatus == .currentlyReading }
    }

    @State private var showAddBook = false

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }
        let new = UserProfile()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    statsHeader

                    if currentlyReading.isEmpty {
                        emptyCurrentlyReading
                    } else {
                        currentlyReadingSection
                    }
                }
                .padding(Theme.Spacing.md)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Shlf")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    private var statsHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.Colors.xpGradient)

                        Text("Level \(profile.currentLevel)")
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.text)
                    }

                    Text("\(profile.totalXP) XP")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Spacer()

                ProgressRing(
                    progress: profile.xpProgressPercentage / 100,
                    gradient: Theme.Colors.xpGradient,
                    size: 70
                )
                .overlay {
                    Text("\(Int(profile.xpProgressPercentage))%")
                        .font(Theme.Typography.caption2)
                        .foregroundStyle(Theme.Colors.text)
                }
            }
            .padding(Theme.Spacing.md)
            .glassEffect()

            HStack(spacing: Theme.Spacing.md) {
                StatCard(
                    title: "Streak",
                    value: "\(profile.currentStreak)",
                    icon: "flame.fill",
                    gradient: Theme.Colors.streakGradient
                )

                StatCard(
                    title: "Books",
                    value: "\(GamificationEngine(modelContext: modelContext).totalBooksRead())",
                    icon: "books.vertical.fill"
                )
            }
        }
    }

    private var emptyCurrentlyReading: some View {
        EmptyStateView(
            icon: "book",
            title: "No Books Reading",
            message: "Start your reading journey by adding your first book",
            actionTitle: "Add Book",
            action: { showAddBook = true }
        )
        .padding(.top, Theme.Spacing.xxl)
    }

    private var currentlyReadingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Currently Reading")
                .font(Theme.Typography.title3)
                .foregroundStyle(Theme.Colors.text)

            ForEach(currentlyReading) { book in
                NavigationLink {
                    BookDetailView(book: book)
                } label: {
                    CurrentlyReadingCard(book: book)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CurrentlyReadingCard: View {
    let book: Book

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 60,
                height: 90
            )

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(book.title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(2)

                Text(book.author)
                    .font(Theme.Typography.callout)
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)

                if let totalPages = book.totalPages {
                    HStack(spacing: Theme.Spacing.xs) {
                        ProgressView(value: book.progressPercentage, total: 100)
                            .tint(Theme.Colors.primary)

                        Text("\(Int(book.progressPercentage))%")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .frame(width: 40, alignment: .trailing)
                    }

                    Text("\(book.currentPage) / \(totalPages) pages")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

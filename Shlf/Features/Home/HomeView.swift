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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    heroSection

                    statsSection

                    if currentlyReading.isEmpty {
                        emptyCurrentlyReading
                    } else {
                        currentlyReadingSection
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .background(Theme.Colors.background)
            .navigationTitle("Shlf")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(greeting)
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.secondaryText)

                Text("•")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.tertiaryText)

                Text("Ready to read?")
                    .font(Theme.Typography.title3)
                    .foregroundStyle(Theme.Colors.text)
            }

            HStack(spacing: Theme.Spacing.lg) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.Colors.xpGradient)

                        Text("Level \(profile.currentLevel)")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.text)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("\(profile.totalXP)")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Colors.text)

                            Text("/ \(profile.xpForNextLevel) XP")
                                .font(Theme.Typography.callout)
                                .foregroundStyle(Theme.Colors.tertiaryText)
                        }

                        ProgressView(value: profile.xpProgressPercentage, total: 100)
                            .tint(Theme.Colors.primary)
                            .scaleEffect(y: 1.5)
                    }
                }

                Spacer()

                ProgressRing(
                    progress: profile.xpProgressPercentage / 100,
                    lineWidth: 10,
                    gradient: Theme.Colors.xpGradient,
                    size: 90
                )
                .overlay {
                    VStack(spacing: 0) {
                        Text("\(Int(profile.xpProgressPercentage))")
                            .font(Theme.Typography.title2)
                            .foregroundStyle(Theme.Colors.text)

                        Text("%")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.tertiaryText)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
            .heroCard()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: Theme.Spacing.md) {
            StatCard(
                title: "Day Streak",
                value: "\(profile.currentStreak)",
                icon: "flame.fill",
                gradient: Theme.Colors.streakGradient
            )

            StatCard(
                title: "Finished",
                value: "\(GamificationEngine(modelContext: modelContext).totalBooksRead())",
                icon: "books.vertical.fill",
                gradient: Theme.Colors.successGradient
            )
        }
    }

    // MARK: - Empty State

    private var emptyCurrentlyReading: some View {
        VStack {
            Spacer()

            EmptyStateView(
                icon: "book.pages",
                title: "No Books Reading",
                message: "Start your reading journey by adding your first book",
                actionTitle: "Add Book",
                action: { showAddBook = true }
            )

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Currently Reading Section

    private var currentlyReadingSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Currently Reading")
                    .sectionHeader()

                Spacer()

                Text("\(currentlyReading.count)")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xxs)
                    .background(Theme.Colors.tertiaryBackground)
                    .clipShape(Capsule())
            }

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

// MARK: - Currently Reading Card

struct CurrentlyReadingCard: View {
    let book: Book

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            BookCoverView(
                imageURL: book.coverImageURL,
                title: book.title,
                width: 70,
                height: 105
            )
            .shadow(color: Theme.Shadow.medium, radius: 8, y: 4)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(book.title)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.text)
                        .lineLimit(2)

                    Text(book.author)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .lineLimit(1)
                }

                if let totalPages = book.totalPages {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack {
                            Text("\(book.currentPage)")
                                .font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Colors.primary)

                            Text("/ \(totalPages) pages")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.tertiaryText)

                            Spacer()

                            Text("\(Int(book.progressPercentage))%")
                                .font(Theme.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Theme.Colors.primary)
                        }

                        ProgressView(value: book.progressPercentage, total: 100)
                            .tint(Theme.Colors.primary)
                            .scaleEffect(y: 1.2)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.tertiaryText)
        }
        .padding(Theme.Spacing.md)
        .cardStyle(elevation: Theme.Elevation.level3)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

//
//  HomeView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.themeColor) private var themeColor
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.dateAdded, order: .reverse)
    private var allBooks: [Book]
    @Query private var allSessions: [ReadingSession] // Trigger refresh when sessions change
    @Binding var selectedTab: Int

    private var currentlyReading: [Book] {
        allBooks.filter { $0.readingStatus == .currentlyReading }
    }

    @State private var showAddBook = false
    @State private var isEditingCards = false
    @State private var showLevelDetail = false

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

    private var engine: GamificationEngine {
        GamificationEngine(modelContext: modelContext)
    }

    // Helper function to get value for each card type
    private func getValue(for cardType: StatCardType) -> String {
        switch cardType {
        case .currentStreak:
            return "\(profile.currentStreak)"
        case .longestStreak:
            return "\(profile.longestStreak)"
        case .level:
            return "\(profile.currentLevel)"
        case .totalXP:
            return "\(profile.totalXP)"
        case .booksRead:
            return "\(engine.totalBooksRead())"
        case .pagesRead:
            return "\(engine.totalPagesRead())"
        case .thisYear:
            return "\(engine.booksReadThisYear())"
        case .thisMonth:
            return "\(engine.booksReadThisMonth())"
        }
    }

    // Helper function to handle card taps
    private func handleCardTap(_ cardType: StatCardType) {
        if cardType == .level {
            // Open Level detail view
            showLevelDetail = true
        } else {
            // Navigate to Stats tab for all other cards
            selectedTab = 2
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    heroSection

                    if !profile.homeCards.isEmpty {
                        statsSection
                    }

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Theme.Spacing.sm) {
                        if !profile.homeCards.isEmpty {
                            if isEditingCards {
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isEditingCards = false
                                    }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(Theme.Colors.success)
                                }
                            } else {
                                Menu {
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isEditingCards = true
                                        }
                                    } label: {
                                        Label("Edit Cards", systemImage: "square.grid.3x3")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title2)
                                        .foregroundStyle(Theme.Colors.secondaryText)
                                }
                            }
                        }

                        Button {
                            showAddBook = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(themeColor.color)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView(selectedTab: $selectedTab)
            }
            .sheet(isPresented: $showLevelDetail) {
                LevelDetailView(profile: profile)
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(greeting)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.text)

            Text("•")
                .font(.title3)
                .foregroundStyle(Theme.Colors.tertiaryText)

            Text("Ready to read?")
                .font(.title3)
                .foregroundStyle(Theme.Colors.secondaryText)

            Spacer()
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(Array(profile.homeCards.enumerated()), id: \.element) { index, cardType in
                StatCard(
                    title: cardType.title,
                    value: getValue(for: cardType),
                    icon: cardType.icon,
                    gradient: cardType.gradient,
                    isEditing: isEditingCards,
                    onRemove: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            profile.removeHomeCard(cardType)
                        }
                    }
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if !isEditingCards {
                        handleCardTap(cardType)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    if !isEditingCards {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditingCards = true
                        }
                    }
                }
                .if(isEditingCards) { view in
                    view
                        .draggable(cardType.rawValue) {
                            // Drag preview
                            StatCard(
                                title: cardType.title,
                                value: getValue(for: cardType),
                                icon: cardType.icon,
                                gradient: cardType.gradient,
                                isEditing: false
                            )
                            .frame(width: 120)
                            .opacity(0.8)
                        }
                        .dropDestination(for: String.self) { items, location in
                            guard let droppedItem = items.first,
                                  let droppedCardType = StatCardType(rawValue: droppedItem),
                                  let fromIndex = profile.homeCards.firstIndex(of: droppedCardType),
                                  let toIndex = profile.homeCards.firstIndex(of: cardType),
                                  fromIndex != toIndex else { return false }

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                profile.homeCardOrder.move(
                                    fromOffsets: IndexSet(integer: fromIndex),
                                    toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
                                )
                                try? modelContext.save()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            return true
                        }
                }
            }
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

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

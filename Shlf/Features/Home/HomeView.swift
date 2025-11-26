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
    @Query private var profiles: [UserProfile]
    @Query(sort: \Book.dateAdded, order: .reverse)
    private var allBooks: [Book]
    @Binding var selectedTab: Int

    private var currentlyReading: [Book] {
        allBooks.filter { $0.readingStatus == .currentlyReading }
    }

    @State private var showAddBook = false
    @State private var isEditingCards = false
    @State private var draggingCard: StatCardType?
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
                                        draggingCard = nil
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
                                .foregroundStyle(Theme.Colors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
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
                Button {
                    if !isEditingCards {
                        handleCardTap(cardType)
                    }
                } label: {
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
                }
                .buttonStyle(.plain)
                .scaleEffect(draggingCard == cardType && isEditingCards ? 1.05 : 1.0)
                .onLongPressGesture(minimumDuration: 0.3) {
                    if !isEditingCards {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditingCards = true
                        }
                    }
                }
                .if(isEditingCards) { view in
                    view
                        .onDrag {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                self.draggingCard = cardType
                            }
                            return NSItemProvider(object: cardType.rawValue as NSString)
                        }
                        .onDrop(of: [.text], delegate: CardDropDelegate(
                            item: cardType,
                            items: profile.homeCards,
                            draggingItem: $draggingCard,
                            onMove: { from, to in
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    profile.homeCardOrder.move(
                                        fromOffsets: IndexSet(integer: from),
                                        toOffset: to
                                    )
                                }
                            }
                        ))
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

// MARK: - Card Drop Delegate

struct CardDropDelegate: DropDelegate {
    let item: StatCardType
    let items: [StatCardType]
    @Binding var draggingItem: StatCardType?
    let onMove: (Int, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem,
              draggingItem != item else { return }

        if let fromIndex = items.firstIndex(of: draggingItem),
           let toIndex = items.firstIndex(of: item),
           fromIndex != toIndex {
            onMove(fromIndex, toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
            draggingItem = nil
        }
        return true
    }
}

#Preview {
    HomeView(selectedTab: .constant(0))
        .modelContainer(for: [Book.self, UserProfile.self], inMemory: true)
}

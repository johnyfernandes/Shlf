//
//  ContentView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var activeSessionLogDestination: ActiveSessionLogDestination?

    private var shouldShowOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding == false || profiles.isEmpty
    }

    private var currentThemeColor: ThemeColor {
        profiles.first?.themeColor ?? .blue
    }

    private var activeSession: ActiveReadingSession? {
        guard ReadingSessionActivityManager.shared.isActive else { return nil }
        return activeSessions.first
    }

    var body: some View {
        Group {
            if let session = activeSession,
               let book = session.book {
                tabShell
                    .tabViewBottomAccessory {
                        ActiveSessionAccessoryView(
                            session: session,
                            book: book
                        ) {
                            activeSessionLogDestination = ActiveSessionLogDestination(bookID: book.id)
                        }
                    }
            } else {
                tabShell
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(currentThemeColor.color)
        .environment(\.themeColor, currentThemeColor)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(item: $activeSessionLogDestination) { destination in
            ActiveSessionLogSheet(bookID: destination.bookID)
        }
        .onAppear {
            showOnboarding = shouldShowOnboarding
        }
    }

    @ViewBuilder
    private var tabShell: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(selectedTab: $selectedTab)
            }

            Tab("Library", systemImage: "books.vertical.fill", value: 1) {
                LibraryView(selectedTab: $selectedTab)
            }

            Tab("Stats", systemImage: "chart.bar.fill", value: 2) {
                StatsView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: 3, role: .search) {
                SearchTabView(selectedTab: $selectedTab)
            }
        }
    }
}

private struct ActiveSessionLogDestination: Identifiable {
    let id = UUID()
    let bookID: UUID
}

private struct ActiveSessionLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var books: [Book]

    private let bookID: UUID

    init(bookID: UUID) {
        self.bookID = bookID
        _books = Query(filter: #Predicate<Book> { $0.id == bookID })
    }

    var body: some View {
        let theme = profiles.first?.themeColor ?? .blue
        Group {
            if let book = books.first {
                LogReadingSessionView(book: book)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading session…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if books.first == nil {
                        dismiss()
                    }
                }
            }
        }
        .environment(\.modelContext, modelContext)
        .environment(\.themeColor, theme)
        .tint(theme.color)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}

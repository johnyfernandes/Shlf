//
//  ContentView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]
    @Query(sort: [SortDescriptor(\Achievement.unlockedAt, order: .reverse)]) private var achievements: [Achievement]

    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var activeSessionLogDestination: ActiveSessionLogDestination?
    @State private var accessoryCoverImage: UIImage?
    @State private var accessoryCoverURL: URL?
    @State private var didSeedAchievementToasts = false
    @State private var toastedAchievementIDs: Set<UUID> = []
    @EnvironmentObject private var toastCenter: ToastCenter

    private var shouldShowOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding == false || profiles.isEmpty
    }

    private var currentThemeColor: ThemeColor {
        profiles.first?.themeColor ?? .blue
    }

    private var activeSession: ActiveReadingSession? {
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
                            book: book,
                            coverImage: accessoryCoverImage
                        ) {
                            activeSessionLogDestination = ActiveSessionLogDestination(bookID: book.id)
                        }
                        .task(id: book.coverImageURL?.absoluteString) {
                            await loadAccessoryCoverIfNeeded(for: book.coverImageURL)
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
            if !didSeedAchievementToasts {
                toastedAchievementIDs = Set(achievements.map(\.id))
                didSeedAchievementToasts = true
            }
            if let profile = profiles.first {
                Task { await NotificationScheduler.shared.refreshSchedule(for: profile) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionLogged)) { _ in
            toastCenter.show(.sessionLogged(tint: currentThemeColor.color), delay: 0.35)
            if let profile = profiles.first {
                Task { await NotificationScheduler.shared.refreshSchedule(for: profile) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("achievementUnlocked"))) { notification in
            if let achievement = notification.object as? Achievement {
                showAchievementToast(achievement)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            toastCenter.updateScenePhase(newValue)
            if newValue == .active, let profile = profiles.first {
                Task { await NotificationScheduler.shared.refreshSchedule(for: profile) }
            }
        }
        .environmentObject(toastCenter)
        .toastHost()
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

    @MainActor
    private func loadAccessoryCoverIfNeeded(for url: URL?) async {
        guard accessoryCoverURL != url else { return }
        accessoryCoverURL = url
        accessoryCoverImage = nil

        guard let url else {
            return
        }

        if let cachedImage = await ImageCacheManager.shared.getImage(for: url) {
            accessoryCoverImage = cachedImage
        }
    }

    private func showAchievementToast(_ achievement: Achievement) {
        guard !toastedAchievementIDs.contains(achievement.id) else { return }
        toastedAchievementIDs.insert(achievement.id)

        let message = String.localizedStringWithFormat(
            String(localized: "Achievement unlocked: %@"),
            achievement.type.localizedName
        )
        toastCenter.show(.achievementUnlocked(title: message, tint: currentThemeColor.color), delay: 0.2)
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
        .environmentObject(ToastCenter())
}

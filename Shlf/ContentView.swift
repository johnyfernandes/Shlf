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
                            // Navigate to Library tab and then to book detail
                            selectedTab = 1
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

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}

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

    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var lastNonSearchTab = 0
    @State private var showQuickAddBook = false
    @State private var quickLogBook: Book?
    @StateObject private var quickActionRouter = QuickActionRouter()

    private var shouldShowOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding == false || profiles.isEmpty
    }

    private var currentThemeColor: ThemeColor {
        profiles.first?.themeColor ?? .blue
    }

    var body: some View {
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
                Color.clear
            }
        }
        .tint(currentThemeColor.color)
        .environment(\.themeColor, currentThemeColor)
        .environmentObject(quickActionRouter)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showQuickAddBook) {
            AddBookView(selectedTab: $selectedTab)
        }
        .sheet(item: $quickLogBook) { book in
            LogReadingSessionView(book: book)
        }
        .onAppear {
            showOnboarding = shouldShowOnboarding
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == 3 {
                selectedTab = lastNonSearchTab
                triggerQuickAction()
            } else {
                lastNonSearchTab = newValue
            }
        }
    }

    private func triggerQuickAction() {
        if let book = quickActionRouter.activeBook {
            quickLogBook = book
        } else {
            showQuickAddBook = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}

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

    private var shouldShowOnboarding: Bool {
        profiles.first?.hasCompletedOnboarding == false || profiles.isEmpty
    }

    private var currentThemeColor: ThemeColor {
        profiles.first?.themeColor ?? .blue
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            LibraryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(1)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(currentThemeColor.color)
        .environment(\.themeColor, currentThemeColor)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            showOnboarding = shouldShowOnboarding
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, Book.self], inMemory: true)
}

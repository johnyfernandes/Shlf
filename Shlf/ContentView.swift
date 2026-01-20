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
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var activeSessionLogDestination: ActiveSessionLogDestination?
    @State private var accessoryCoverImage: UIImage?
    @State private var accessoryCoverURL: URL?
    @State private var showSessionLoggedToast = false
    @State private var sessionLoggedToastID = UUID()

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
        .overlay(alignment: .top) {
            if showSessionLoggedToast {
                SessionLoggedToast(animate: showSessionLoggedToast) {
                    dismissSessionLoggedToast()
                }
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            showOnboarding = shouldShowOnboarding
        }
        .onReceive(NotificationCenter.default.publisher(for: .readingSessionLogged)) { _ in
            triggerSessionLoggedToast()
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

    private func triggerSessionLoggedToast() {
        sessionLoggedToastID = UUID()
        let toastID = sessionLoggedToastID

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard toastID == sessionLoggedToastID else { return }
            Haptics.impact(.light)
            withAnimation(Theme.Animation.smooth) {
                showSessionLoggedToast = true
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard toastID == sessionLoggedToastID else { return }
            withAnimation(Theme.Animation.smooth) {
                showSessionLoggedToast = false
            }
        }
    }

    private func dismissSessionLoggedToast() {
        sessionLoggedToastID = UUID()
        withAnimation(Theme.Animation.smooth) {
            showSessionLoggedToast = false
        }
    }
}

private struct SessionLoggedToast: View {
    @Environment(\.themeColor) private var themeColor
    let animate: Bool
    let onDismiss: () -> Void
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeColor.color)
                .symbolEffect(.bounce, value: animate)

            Text(String(localized: "Session logged"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(themeColor.color.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Theme.Shadow.medium, radius: 10, y: 6)
        .contentShape(Capsule())
        .onTapGesture {
            onDismiss()
        }
        .offset(y: dragOffset < 0 ? dragOffset : 0)
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height < 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height < -16 {
                        onDismiss()
                    }
                }
        )
        .animation(.easeOut(duration: 0.15), value: dragOffset)
        .accessibilityLabel(Text(String(localized: "Session logged")))
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

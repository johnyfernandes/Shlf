//
//  ContentView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 27/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.title) private var allBooks: [Book]
    @Query private var profiles: [UserProfile]
    @Query private var activeSessions: [ActiveReadingSession]

    #if DEBUG
    @AppStorage("debugWatchThemeOverrideEnabled") private var debugThemeOverrideEnabled = false
    @AppStorage("debugWatchThemeOverrideColor") private var debugThemeOverrideRawValue = ThemeColor.blue.rawValue
    #endif

    private var currentBooks: [Book] {
        allBooks.filter { $0.readingStatus == .currentlyReading }
    }

    private var activeSession: ActiveReadingSession? {
        activeSessions.first
    }

    private var profile: UserProfile {
        if let existing = profiles.first {
            return existing
        }

        // CRITICAL: Check again after fetching to prevent race condition
        let descriptor = FetchDescriptor<UserProfile>()
        if let existingAfterFetch = try? modelContext.fetch(descriptor).first {
            return existingAfterFetch
        }

        // Now safe to create
        let new = UserProfile()
        modelContext.insert(new)
        try? modelContext.save() // Save immediately to prevent other threads from creating
        return new
    }

    private var currentThemeColor: ThemeColor {
        #if DEBUG
        if debugThemeOverrideEnabled,
           let override = ThemeColor(rawValue: debugThemeOverrideRawValue) {
            return override
        }
        #endif
        return profile.themeColor
    }

    var body: some View {
        NavigationStack {
            // Active session indicator at the top
            if let session = activeSession, let book = session.book {
                VStack(spacing: 8) {
                    NavigationLink(destination: LogSessionWatchView(book: book)) {
                        HStack(spacing: 8) {
                            // Live indicator
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                                .shadow(color: .green.opacity(0.6), radius: 4, x: 0, y: 0)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(book.title)
                                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                                    .lineLimit(1)

                                HStack(spacing: 4) {
                                    Text(
                                        String.localizedStringWithFormat(
                                            String(localized: "%lld pages"),
                                            session.pagesRead
                                        )
                                    )
                                        .font(.system(.caption2, design: .rounded))
                                        .foregroundStyle(.secondary)

                                    if session.isPaused {
                                        Text(verbatim: "•")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text("Paused")
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }

                            Spacer(minLength: 0)

                            Image(systemName: "chevron.forward")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }

            if currentBooks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("No books")
                        .font(.headline)

                    Text("Start reading on your iPhone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .toolbar { settingsToolbar }
            } else {
                List {
                    ForEach(currentBooks) { book in
                        NavigationLink(destination: BookDetailWatchView(book: book)) {
                            BookRowWatch(book: book)
                        }
                    }
                }
                .navigationTitle("Reading")
                .toolbar { settingsToolbar }
            }
        }
        .tint(currentThemeColor.color)
        .environment(\.themeColor, currentThemeColor)
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        if profile.showSettingsOnWatch {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsWatchView()) {
                    Image(systemName: "gearshape.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

struct BookRowWatch: View {
    @Environment(\.themeColor) private var themeColor
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.headline)
                .lineLimit(2)

            Text(book.author)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let totalPages = book.totalPages {
                HStack(spacing: 4) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "%lld/%lld"),
                            book.currentPage,
                            totalPages
                        )
                    )
                        .font(.caption2)
                        .foregroundStyle(themeColor.color)

                    ProgressView(value: Double(book.currentPage), total: Double(totalPages))
                        .tint(themeColor.color)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, ReadingSession.self], inMemory: true)
}

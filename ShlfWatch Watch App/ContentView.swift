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
        let new = UserProfile()
        modelContext.insert(new)
        return new
    }

    var body: some View {
        NavigationStack {
            // Active session indicator at the top
            if let session = activeSession, let book = session.book {
                VStack(spacing: 0) {
                    NavigationLink(destination: LogSessionWatchView(book: book)) {
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reading Now")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(book.title)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(session.pagesRead)p")
                                .font(.caption2)
                                .foregroundStyle(.cyan)

                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.green.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    Divider()
                        .padding(.horizontal)
                }
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
    }

    @ToolbarContentBuilder
    private var settingsToolbar: some ToolbarContent {
        if profile.showSettingsOnWatch {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsWatchView()) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.cyan)
                }
            }
        }
    }
}

struct BookRowWatch: View {
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
                    Text("\(book.currentPage)/\(totalPages)")
                        .font(.caption2)
                        .foregroundStyle(.cyan)

                    ProgressView(value: Double(book.currentPage), total: Double(totalPages))
                        .tint(.cyan)
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

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

    private var currentBooks: [Book] {
        allBooks.filter { $0.readingStatus == .currentlyReading }
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

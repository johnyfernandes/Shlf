//
//  ContentView.swift
//  ShlfWatch Watch App
//
//  Created by João Fernandes on 27/11/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Book.title) private var allBooks: [Book]

    private var currentBooks: [Book] {
        allBooks.filter { $0.readingStatus == .currentlyReading }
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
            } else {
                List {
                    ForEach(currentBooks) { book in
                        NavigationLink(destination: BookDetailWatchView(book: book)) {
                            BookRowWatch(book: book)
                        }
                    }
                }
                .navigationTitle("Reading")
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

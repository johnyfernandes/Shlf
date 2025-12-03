//
//  QuotesListWatchView.swift
//  ShlfWatch Watch App
//
//  Created by Claude on 03/12/2025.
//

import SwiftUI

struct QuotesListWatchView: View {
    let quotes: [Quote]

    private var sortedQuotes: [Quote] {
        quotes.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        List {
            ForEach(sortedQuotes) { quote in
                NavigationLink {
                    QuoteDetailWatchView(quote: quote)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quote.excerpt)
                            .font(.footnote)
                            .lineLimit(3)

                        HStack {
                            if let page = quote.pageNumber {
                                Text("Page \(page)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            if quote.isFavorite {
                                Spacer()
                                Image(systemName: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Quotes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QuoteDetailWatchView: View {
    let quote: Quote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Quote text
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if quote.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .font(.caption)

                    Text(quote.text)
                        .font(.footnote)
                }

                // Metadata
                if let page = quote.pageNumber {
                    HStack {
                        Image(systemName: "book.pages")
                        Text("Page \(page)")
                        Spacer()
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Image(systemName: "calendar")
                    Text(quote.dateAdded, style: .date)
                    Spacer()
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                // Personal note
                if let note = quote.note, !note.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Personal Note")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(note)
                            .font(.caption2)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Quote")
        .navigationBarTitleDisplayMode(.inline)
    }
}

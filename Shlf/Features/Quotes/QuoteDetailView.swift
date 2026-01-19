//
//  QuoteDetailView.swift
//  Shlf
//
//  Created by Claude on 03/12/2025.
//

import SwiftUI
import SwiftData

struct QuoteDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Bindable var quote: Quote
    let book: Book

    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                // Quote text
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Button {
                            quote.isFavorite.toggle()
                            try? modelContext.save()
                        } label: {
                            Image(systemName: quote.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                        }
                    }
                    .font(.title3)

                    Text(quote.text)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.text)
                }
                .padding(Theme.Spacing.md)
                .cardStyle()

                // Metadata
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    if let page = quote.pageNumber {
                        HStack(spacing: 12) {
                            Image(systemName: "book.pages")
                                .font(.caption)
                                .foregroundStyle(themeColor.color)
                                .frame(width: 20)

                            Text("Page")
                                .font(.caption)
                                .foregroundStyle(Theme.Colors.secondaryText)

                            Spacer()

                            Text("\(page)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.Colors.text)
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(themeColor.color)
                            .frame(width: 20)

                        Text("Added")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text(quote.dateAdded.formatted(date: .long, time: .shortened))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.text)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.caption)
                            .foregroundStyle(themeColor.color)
                            .frame(width: 20)

                        Text("Book")
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.secondaryText)

                        Spacer()

                        Text(book.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.Colors.text)
                            .lineLimit(1)
                    }
                }
                .padding(Theme.Spacing.md)
                .cardStyle()

                // Personal note
                if let note = quote.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Personal Note")
                            .font(Theme.Typography.headline)

                        Text(note)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .padding(Theme.Spacing.md)
                    .cardStyle()
                }

            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.Colors.background)
        .navigationTitle("Quote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        shareQuote()
                    } label: {
                        Label("Share Quote", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Quote", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(themeColor.color)
                }
            }
        }
        .alert("Delete Quote?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteQuote()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This quote will be permanently deleted.")
        }
    }

    private func shareQuote() {
        var shareText = "\"\(quote.text)\"\n\n"
        if let page = quote.pageNumber {
            shareText += "Page \(page), "
        }
        shareText += "\(book.title) by \(book.author)"

        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            // Find the topmost presented view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            activityVC.popoverPresentationController?.sourceView = topVC.view
            topVC.present(activityVC, animated: true)
        }
    }

    private func deleteQuote() {
        modelContext.delete(quote)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    NavigationStack {
        QuoteDetailView(
            quote: Quote(
                book: nil,
                text: "To be or not to be, that is the question. Whether 'tis nobler in the mind to suffer the slings and arrows of outrageous fortune.",
                pageNumber: 47,
                note: "This is one of the most famous soliloquies in literature.",
                isFavorite: true
            ),
            book: Book(title: "Hamlet", author: "William Shakespeare")
        )
    }
    .modelContainer(for: [Quote.self, Book.self], inMemory: true)
}

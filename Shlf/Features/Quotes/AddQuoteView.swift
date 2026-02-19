//
//  AddQuoteView.swift
//  Shlf
//
//  Created by Claude on 03/12/2025.
//

import SwiftUI
import SwiftData

struct AddQuoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeColor) private var themeColor
    @Environment(\.locale) private var locale

    let book: Book
    let prefillPage: Int?

    @State private var quoteText = ""
    @State private var pageNumber = ""
    @State private var personalNote = ""
    @State private var isFavorite = false

    private let maxCharacters = 1000

    init(book: Book, prefillPage: Int? = nil) {
        self.book = book
        self.prefillPage = prefillPage
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Quotes.Add.QuoteText") {
                    TextEditor(text: $quoteText)
                        .frame(minHeight: 150)

                    HStack {
                        Spacer()
                        Text(
                            String.localizedStringWithFormat(
                                localized("Common.CountFormat %lld %lld", locale: locale),
                                quoteText.count,
                                maxCharacters
                            )
                        )
                            .font(.caption)
                            .foregroundStyle(quoteText.count > maxCharacters ? .red : .secondary)
                    }
                }

                Section("Quotes.Add.Details") {
                    HStack {
                        Text("Quotes.Add.PageNumberOptional")
                        Spacer()
                        TextField("Common.Page", text: $pageNumber)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Toggle("Quotes.Add.MarkFavorite", isOn: $isFavorite)
                }

                Section("Quotes.Add.PersonalNoteOptional") {
                    TextEditor(text: $personalNote)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Quotes.Add.Title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Common.Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Common.Save") {
                        saveQuote()
                    }
                    .disabled(quoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || quoteText.count > maxCharacters)
                }
            }
            .onAppear {
                if let page = prefillPage {
                    pageNumber = "\(page)"
                }
            }
        }
    }

    private func saveQuote() {
        let quote = Quote(
            book: book,
            text: quoteText.trimmingCharacters(in: .whitespacesAndNewlines),
            pageNumber: Int(pageNumber),
            note: personalNote.isEmpty ? nil : personalNote,
            isFavorite: isFavorite
        )

        modelContext.insert(quote)

        if book.quotes == nil {
            book.quotes = []
        }
        book.quotes?.append(quote)

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    AddQuoteView(book: Book(title: "Test Book", author: "Test Author"))
        .modelContainer(for: [Book.self, Quote.self], inMemory: true)
}

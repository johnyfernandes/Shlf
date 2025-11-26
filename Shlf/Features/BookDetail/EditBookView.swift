//
//  EditBookView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct EditBookView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var book: Book

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Information") {
                    TextField("Title", text: $book.title)
                    TextField("Author", text: $book.author)
                    TextField("ISBN", text: Binding(
                        get: { book.isbn ?? "" },
                        set: { book.isbn = $0.isEmpty ? nil : $0 }
                    ))
                }

                Section("Details") {
                    TextField("Total Pages", value: $book.totalPages, format: .number)
                        .keyboardType(.numberPad)

                    TextField("Current Page", value: $book.currentPage, format: .number)
                        .keyboardType(.numberPad)
                }

                Section("Type & Status") {
                    Picker("Book Type", selection: $book.bookType) {
                        ForEach(BookType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }

                    Picker("Reading Status", selection: $book.readingStatus) {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Text(status.rawValue)
                                .tag(status)
                        }
                    }
                }

                Section("Rating") {
                    Picker("Rating", selection: Binding(
                        get: { book.rating ?? 0 },
                        set: { book.rating = $0 == 0 ? nil : $0 }
                    )) {
                        Text("None").tag(0)
                        ForEach(1...5, id: \.self) { rating in
                            HStack {
                                ForEach(0..<rating, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                }
                            }
                            .tag(rating)
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $book.notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditBookView(book: Book(
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald"
    ))
}

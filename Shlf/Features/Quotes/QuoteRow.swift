//
//  QuoteRow.swift
//  Shlf
//
//  Created by Claude on 03/12/2025.
//

import SwiftUI

struct QuoteRow: View {
    let quote: Quote

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .top) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)

                Text(quote.excerpt)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.text)
                    .lineLimit(3)

                Spacer()

                if quote.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }

            HStack {
                if let page = quote.pageNumber {
                    Text("Page \(page)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }

                Spacer()

                Text(quote.dateAdded, style: .date)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.tertiaryText)
            }
        }
        .padding(Theme.Spacing.md)
        .cardStyle()
    }
}

#Preview {
    QuoteRow(quote: Quote(
        book: nil,
        text: "To be or not to be, that is the question. Whether 'tis nobler in the mind to suffer the slings and arrows of outrageous fortune.",
        pageNumber: 47,
        isFavorite: true
    ))
    .padding()
}

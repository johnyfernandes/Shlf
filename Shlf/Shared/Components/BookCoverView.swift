//
//  BookCoverView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI

struct BookCoverView: View {
    let imageURL: URL?
    let title: String
    let width: CGFloat
    let height: CGFloat

    init(
        imageURL: URL?,
        title: String,
        width: CGFloat = 100,
        height: CGFloat = 150
    ) {
        self.imageURL = imageURL
        self.title = title
        self.width = width
        self.height = height
    }

    var body: some View {
        Group {
            if let imageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderView
                }
            } else {
                placeholderView
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
        .shadow(color: Theme.Shadow.medium, radius: 8, y: 4)
    }

    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.secondaryBackground)

            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "book.closed")
                    .font(.title)
                    .foregroundStyle(Theme.Colors.tertiaryText)

                Text(title)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BookCoverView(
            imageURL: nil,
            title: "The Great Gatsby"
        )

        BookCoverView(
            imageURL: URL(string: "https://covers.openlibrary.org/b/id/123-L.jpg"),
            title: "1984",
            width: 120,
            height: 180
        )
    }
    .padding()
}

//
//  BookCoverView.swift
//  Shlf
//
//  Created by João Fernandes on 26/11/2025.
//

import SwiftUI
import UIKit

struct BookCoverView: View {
    let imageURL: URL?
    let title: String
    let width: CGFloat
    let height: CGFloat
    @State private var loadedImage: UIImage?

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
                CachedAsyncImage(
                    url: imageURL,
                    content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    },
                    placeholder: {
                    loadingPlaceholder
                    },
                    onImageLoaded: { image in
                        loadedImage = image
                    }
                )
            } else {
                placeholderView
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
        .shadow(color: Theme.Shadow.medium, radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.3), value: imageURL)
        .contextMenu {
            if imageURL != nil {
                Button {
                    withImage { image in
                        UIPasteboard.general.image = image
                    }
                } label: {
                    Label("Copy Image", systemImage: "doc.on.doc")
                }

                Button {
                    withImage { image in
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    }
                } label: {
                    Label("Save Image", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    private func withImage(_ action: @escaping (UIImage) -> Void) {
        if let loadedImage {
            action(loadedImage)
            return
        }

        guard let imageURL else { return }

        Task {
            if let image = await ImageCacheManager.shared.getImage(for: imageURL) {
                await MainActor.run {
                    loadedImage = image
                    action(image)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .fill(Theme.Colors.secondaryBackground)
                .overlay(
                    ShimmerEffect()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                )

            Image(systemName: "book.closed")
                .font(.title)
                .foregroundStyle(Theme.Colors.tertiaryText.opacity(0.3))
        }
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

// MARK: - Shimmer Effect

struct ShimmerEffect: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.clear, location: 0),
                    .init(color: Color.white.opacity(0.1), location: 0.4),
                    .init(color: Color.white.opacity(0.2), location: 0.5),
                    .init(color: Color.white.opacity(0.1), location: 0.6),
                    .init(color: Color.clear, location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
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
